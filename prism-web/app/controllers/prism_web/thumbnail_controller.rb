module PrismWeb
  class ThumbnailController < ApplicationController
    skip_before_action :authenticate_prism!

    def share
      @share_token = ShareToken.find_by!(token: params[:token])

      respond_to do |format|
        format.html { render layout: "prism_web/embed" }
        format.json { render json: { data: @share_token } }
      end
    end
  end
end