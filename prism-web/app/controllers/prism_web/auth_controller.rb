module PrismWeb
  class AuthController < ApplicationController
    def redirect
      redirect_to "#{Prism.config.host_app_base_url || ''}/login"
    end
  end
end