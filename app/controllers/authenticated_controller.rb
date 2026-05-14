# frozen_string_literal: true

class AuthenticatedController < ApplicationController
  layout "authenticated"

  before_action :require_authentication
  before_action :set_paper_trail_whodunnit

  helper_method :current_user

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end

  def require_authentication
    redirect_to login_path, alert: "Authentication required." unless current_user
  end

  def set_paper_trail_whodunnit
    PaperTrail.request.whodunnit = current_user&.id&.to_s
  end
end
