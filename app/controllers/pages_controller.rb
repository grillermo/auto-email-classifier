# frozen_string_literal: true

class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[privacy terms_of_service]

  def privacy
  end

  def terms_of_service
  end
end
