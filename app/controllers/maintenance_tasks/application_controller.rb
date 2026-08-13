# frozen_string_literal: true

module MaintenanceTasks
  # Base class for all controllers used by this engine.
  #
  # Can be extended to add different authentication and authorization code.
  class ApplicationController < ActionController::Base
    BULMA_CDN = "https://cdn.jsdelivr.net"

    content_security_policy do |policy|
      policy.style_src(
        BULMA_CDN,
        # ruby syntax highlighting
        "'sha256-y9V0na/WU44EUNI/HDP7kZ7mfEci4PAOIjYOOan6JMA='",
      )
      policy.script_src(
        # page refresh script
        "'sha256-2RPaBS4XCMLp0JJ/sW407W9l4qjC+WQAHmTOFJTGfqo='",
      )
      policy.frame_ancestors(:self)
    end

    before_action do
      request.content_security_policy_nonce_generator ||=
        ->(_request) { SecureRandom.base64(16) }

      # Rails 6.0 added per-request nonce directives; on 5.2 the set is the
      # hardcoded ActionDispatch NONCE_DIRECTIVES = %w[script-src], so this
      # setter does not exist and calling it raises NoMethodError. Nothing else
      # is needed on 5.2: the layout's inline <style> block is admitted by the
      # 'sha256-...' source already listed in style_src above, which matches
      # whether or not the element also carries an unusable nonce attribute.
      if request.respond_to?(:content_security_policy_nonce_directives=)
        request.content_security_policy_nonce_directives = ["style-src"]
      end
    end

    protect_from_forgery with: :exception
  end
end
