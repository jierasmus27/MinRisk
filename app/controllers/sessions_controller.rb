# frozen_string_literal: true

class SessionsController < ApplicationController
  layout "session"

  def new
    redirect_to companies_path if session[:user_id].present?
  end

  def create
    user = User.authenticate_by(operator_id: session_params[:operator_id]&.strip, password: session_params[:password])
    if user
      session[:user_id] = user.id
      redirect_to companies_path, notice: "Session initialized."
    else
      flash.now[:alert] = "Invalid operator ID or authentication key."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    session.delete(:user_id)
    redirect_to login_path, notice: "Signed out."
  end

  private

  def session_params
    params.permit(:operator_id, :password)
  end
end
