#
# Copyright (C) 2011 Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.
#

require 'securerandom'

class EportfolioEntriesController < ApplicationController
  include EportfolioPage
  before_filter :rich_content_service_config

  def create
    @portfolio = Eportfolio.find(params[:eportfolio_id])
    if authorized_action(@portfolio, @current_user, :update)
      @category = @portfolio.eportfolio_categories.find(params[:eportfolio_entry].delete(:eportfolio_category_id))

      page_names = @category.eportfolio_entries.map{|c| c.name}
      @page = @portfolio.eportfolio_entries.build(eportfolio_entry_params)
      @page.eportfolio_category = @category
      @page.parse_content(params)
      respond_to do |format|
        if @page.save
          format.html { redirect_to eportfolio_entry_url(@portfolio, @page) }
          format.json { render :json => @page.as_json(:methods => :category_slug) }
        else
          format.json { render :json => @page.errors }
        end
      end
    end
  end

  def show
    @portfolio = Eportfolio.find(params[:eportfolio_id])
    if params[:verifier] == @portfolio.uuid
      session[:eportfolio_ids] ||= []
      session[:eportfolio_ids] << @portfolio.id
      session[:permissions_key] = SecureRandom.uuid
    end
    if authorized_action(@portfolio, @current_user, :read)
      if params[:category_name]
        @category = @portfolio.eportfolio_categories.where(slug: params[:category_name]).first
      end
      if params[:id]
        @page = @portfolio.eportfolio_entries.find(params[:id])
      elsif params[:entry_name] && @category
        @page = @category.eportfolio_entries.where(slug: params[:entry_name]).first
      end
      if !@page
        flash[:notice] = t('notices.missing_page', "Couldn't find that page")
        redirect_to eportfolio_url(@portfolio.id)
        return
      end
      @category = @page.eportfolio_category
      eportfolio_page_attributes
      render "eportfolios/show"
    end
  end

  def update
    @portfolio = Eportfolio.find(params[:eportfolio_id])
    if authorized_action(@portfolio, @current_user, :update)
      @entry = @portfolio.eportfolio_entries.find(params[:id])
      @entry.parse_content(params) if params[:section_count]
      category_id = params[:eportfolio_entry].delete(:eportfolio_category_id)
      entry_params = eportfolio_entry_params
      if category_id && category_id.to_i != @entry.eportfolio_category_id
        category = @portfolio.eportfolio_categories.find(category_id)
        entry_params[:eportfolio_category] = category
      end
      respond_to do |format|
        if @entry.update_attributes!(entry_params)
          format.html { redirect_to eportfolio_entry_url(@portfolio, @entry) }
          format.json { render :json => @entry }
        else
          format.html { redirect_to eportfolio_entry_url(@portfolio, @entry) }
          format.json { render :json => @entry.errors, :status => :bad_request }
        end
      end
    end
  end


  def destroy
    @portfolio = Eportfolio.find(params[:eportfolio_id])
    if authorized_action(@portfolio, @current_user, :update)
      @entry = @portfolio.eportfolio_entries.find(params[:id])
      @category = @entry.eportfolio_category
      respond_to do |format|
        if @entry.destroy
          format.html { redirect_to eportfolio_category_url(@portfolio, @category) }
          format.json { render :json => @entry }
        else
        end
      end
    end
  end

  def attachment
    @portfolio = Eportfolio.find(params[:eportfolio_id])
    if authorized_action(@portfolio, @current_user, :read)
      @entry = @portfolio.eportfolio_entries.find(params[:entry_id])
      @category = @entry.eportfolio_category
      @attachment = @portfolio.user.all_attachments.where(uuid: params[:attachment_id]).first
      # @entry.check_for_matching_attachment_id
      begin
        redirect_to file_download_url(@attachment, { :verifier => @attachment.uuid })
      rescue
        raise t('errors.not_found', "Not Found")
      end
    end
  end

  def submission
    @portfolio = Eportfolio.find(params[:eportfolio_id])
    if authorized_action(@portfolio, @current_user, :read)
      @entry = @portfolio.eportfolio_entries.find(params[:entry_id])
      @category = @entry.eportfolio_category
      @submission = @portfolio.user.submissions.find(params[:submission_id])
      @assignment = @submission.assignment
      @user = @submission.user
      @context = @assignment.context
      # @entry.check_for_matching_attachment_id
      @headers = false
      render "submissions/show_preview"
    end
  end

  protected
  def rich_content_service_config
    rce_js_env(:basic)
  end

  def eportfolio_entry_params
    strong_params.require(:eportfolio_entry).permit(:name, :allow_comments, :show_comments)
  end
end
