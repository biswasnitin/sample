class ApplicationController < ActionController::Base
  include ActionController::Instrumentation # enables AS::Notifications, used by Skylight

  include Controllers::Exceptions

  before_action :set_sentry_context
  before_action :set_last_active_at
  before_action :set_csrf_header
  before_action :banned?
  protect_from_forgery

  rescue_from ActionController::UnknownFormat, with: :raise_not_acceptable
  rescue_from Mongo::Error::SocketError, Mongo::Error::NoServerAvailable, with: :exit_after_mongo_connection_failure!

  def raise_not_acceptable
    return head(:not_acceptable)
  end

  def exit_after_mongo_connection_failure! ex
    raise ex unless Rails.env.production?
    Sentry.capture_exception ex
    exit!
  end

  # layout :application
  helper :links, :social, :json

  def head_ok
    head :ok
  end


protected
  def authenticate_user!(options={})
    if !signed_in? && request.get?
      redirect_to "#{new_user_session_url}?redirectTo=#{request.original_url}"
    else
      super(options)
    end
  end

  def json_response(options={})
    previous_formats = lookup_context.formats
    render_to_string options.merge(formats: [:json], layout: false)
  ensure
    # cleanup, otherwise the rendered format is still set to json
    lookup_context.rendered_format = nil
    lookup_context.formats = previous_formats
  end
  helper_method :json_response

  #
  # before_filters
  #
  def set_last_active_at
    # sacrifice accuracy of the timestamp (within 1 day) so that we don't have to
    # write a user attribute for every single request
    if current_user && (current_user.last_active_at.nil? || current_user.last_active_at < 1.day.ago)
      current_user.set last_active_at: Time.now
    end
  end

  def set_sentry_context
    if current_user.present?
      Sentry.set_user(id: current_user.id)
    end
    SentryHelper.append_trace_id
  end

  def render_nothing(options={})
    respond_to do |format|
      format.html do
        render options.merge(plain: '')
      end
      format.json do
        render options.merge(json: {})
      end
    end
  end

  def render_empty(options={})
    respond_to do |format|
      format.html do
        render options.merge(inline: '')
      end
      format.json do
        render_empty_json(options)
      end
    end
  end

  def render_empty_json(options={})
    render options.merge(inline: '{}', layout: 'application')
  end

  #
  # ssl
  #
  def secure_protocol
    use_ssl? ? 'https' : 'http'
  end
  helper_method :secure_protocol

  def use_ssl?
    Rails.env.production? || Rails.env.staging?
  end

  def authorize_admin
    raise_http_error(404) unless current_user and current_user.admin?
  end

private


  def is_admin_layout?
    false
  end

  def set_csrf_header
    response.headers['X-CSRF-Token'] = session[:_csrf_token] ||= SecureRandom.base64(32)
  end

  def safe_url(url)
    whitelist_domains = AppConfig.instance.whitelisted_host
    location = URI.parse(url)
    whitelist_domains.include?(location.host) ? location.to_s : location.path
  end


  def banned?
    sign_out(current_user) if current_user&.banned?
  end
 
end
