# frozen_string_literal: true

class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[home privacy terms_of_service]

  def home
  end

  def privacy
  end

  def terms_of_service
  end
end
