#--
# Copyright (c) 2009-2010 Novell, Inc.
# 
# All Rights Reserved.
# 
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License
# as published by the Free Software Foundation.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, contact Novell, Inc.
# 
# To contact Novell about this file by physical or electronic mail,
# you may find current contact information at www.novell.com
#++
# = Active Directory controller
# Provides access to configuration of Active Directory

#require 'client_exception'

class ActivedirectoryController < ApplicationController
  
  layout 'main'

  # Initialize GetText and Content-Type.
  FastGettext.add_text_domain "webyast-activedirectory", :path => "locale"
  
  def index
    authorize! :read, Activedirectory
    @poll_for_updates = true
    
    begin
      @activedirectory = Activedirectory.find
      Rails.logger.debug "ad: #{@activedirectory.inspect}"
      
    rescue ActiveResource::ResourceNotFound => e
      flash[:error] = _("Cannot read Active Directory client configuraton.")
      @activedirectory  = nil
      render :index and return
    end
    return unless @activedirectory
  end

  # PUT action
  # Write AD client configuration
  def update
    authorize! :write, Activedirectory
    @poll_for_updates = false
    
    if params["activedirectory"] == nil || params["activedirectory"] == {}
      raise InvalidParameters.new :activedirectory => "Missing"
    end
    
    if request.format.html? #HTML
      Rails.logger.debug "HTML FORMAT"
      
      begin
        params[:activedirectory][:enabled] = params[:activedirectory][:enabled] == "true"
        args = params["activedirectory"]
        args = {} if args.nil?
        @activedirectory = Activedirectory.new
        @activedirectory.load args
        @activedirectory.save
        
        flash[:message] = _("Active Directory client configuraton successfully written.")
        redirect_success
        
      rescue ActivedirectoryError => e
        # credentials required for joining the domain
        if e.id == "not_member"
          flash[:mesage] = _("Machine is not member of given domain. Enter the credentials needed for join.")
          @activedirectory.administrator = ""
          @activedirectory.password = ""
          @activedirectory.machine = ""
          render :index and return
          
        elsif e.id == "join_error"
          flash[:error] = _("Error while joining Active Directory domain: %s") % e.message
          render :index and return
          
        elsif e.id == "leave_error"
          flash[:error] = _("Error while leaving Active Directory domain: %s") % e.message
          render :index and return
        else
          Rails.logger.debug "ERROR INSPECT #{e.inspect}"
          flash[:error] = _("Error while saving Active Directory client configuration.")
        end
      end
    else #REST API
      Rails.logger.debug "XML FORMAT"
      args = params["activedirectory"]
      args = {} if args.nil?

      @activedirectory = Activedirectory.new
      @activedirectory.load args
      @activedirectory.save
      
      respond_to do |format|
        format.xml  { render :xml => @activedirectory.to_xml}
        format.json { render :json => @activedirectory.to_json}
      end
    end
    
  end

  # GET action
  # Read AD client settings
  def show
    authorize! :read, Activedirectory
    ad = Activedirectory.find

    respond_to do |format|
      format.xml  { render :xml => ad.to_xml}
      format.json { render :json => ad.to_json}
    end
  end

  # See update
  def create
    update
  end

end
