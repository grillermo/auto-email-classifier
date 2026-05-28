# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  def new
    render :new
  end
end
