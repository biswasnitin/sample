module Controllers::Exceptions
  extend ActiveSupport::Concern

  included do

    if AppConfig.instance.rescue_from_controller_exceptions
      rescue_from Exception do |e|
        raise_or_render(e, 500, nil, true)
      end
    end

    rescue_from Errors::Http::Status do |e|
      raise_or_render(e, e.code, e.message, e.loggable?)
    end

    rescue_from Mongoid::Errors::DocumentNotFound do |e|
      raise_or_render(e, 404, nil, false)
    end

    rescue_from CanCan::AccessDenied do |e|
      if e.subject.nil?
        raise_or_render(e, 404, e.message, false)
      else
        raise_or_render(e, 403, e.message || "You do not have access to this page.", false)
      end
    end
  end

  def raise_http_error(status_code=404, message=nil)
    raise Errors::Http.status_error(status_code, message)
  end

  def render_error(status_code, code=nil, message=nil)
    # Support status_code being passed as an integer (403) or a symbol (:forbidden)
    status_code = Rack::Utils.status_code(status_code)

    if message
      flash.now[:error] = message
      logger.info "Rendering #{status_code} with message: #{message}"
    end

    # Render an error payload only if a code or message was provided.
    error_payload = (code.nil? && message.nil?) ? {} : ErrorPayload.new(code, message)
    render_error_payload(status_code, error_payload)
  end

  # Renders a standard format error from a mutation (https://github.com/cypriss/mutations) outcome.
  def render_outcome_error(outcome)
    code = outcome.errors.symbolic.fetch(:code, nil)

    if code.present?
      message = outcome.errors.message.fetch(:code, nil)
    else
      # This handles required field validations - the code is the field name, the message is "required".
      code = outcome.errors.symbolic.first&.first
      message = outcome.errors.symbolic.first&.[](1) # This awkward code is a nil-safe array access.
    end

    render_error(
      outcome.errors.symbolic.fetch(:status_code, :unprocessable_entity),
      code,
      message
    )
  end

  def render_error_payload(status_code, error)
    error_template = status_code
    error_template = 404 if status_code == 410

    @body_class = 'error'

    respond_to do |format|
      format.html { render "errors/#{error_template}", layout: 'static', status: status_code }
      format.json { render json: error, status: status_code }
      format.xml  { head status_code }
      format.any  { head status_code }
    end
  end

  def raise_or_render(e, status_code=404, message=nil, notify=false)
    if Uniiverse::Application.config.consider_all_requests_local
      if is_navigational_format?
        raise e
      else
        # The code to handle catching errors is a Rack app in ActionDispatch::DebugExceptions
        # That app only responds with HTML, so we manually log JSON exceptions here.
        log_error(e)
        render_error(status_code, nil, message)
      end
    else
      Sentry.capture_exception(e) if notify
      render_error(status_code, nil, message)
    end
  end

  # this code is largely copied from ActionDispatch::DebugExceptions
  def log_error(exception)
    bc = ActiveSupport::BacktraceCleaner.new
    wrapper = ActionDispatch::ExceptionWrapper.new(bc, exception)

    trace = wrapper.application_trace
    trace = wrapper.framework_trace if trace.empty?

    ActiveSupport::Deprecation.silence do
      message = "\n#{exception.class} (#{exception.message}):\n"
      message << exception.annoted_source_code.to_s if exception.respond_to?(:annoted_source_code)
      message << "  " << trace.join("\n  ")
      Rails.logger.fatal("#{message}\n\n")
    end
  end
end
