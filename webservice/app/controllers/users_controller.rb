include ApplicationHelper

class UsersController < ApplicationController

  before_filter :login_required

  require "scr"
#--------------------------------------------------------------------------------
#
#local methods
#
#--------------------------------------------------------------------------------


  def get_userList
    if permissionCheck( "org.opensuse.yast.webservice.read-userlist")
       ret = Scr.execute("LANG=en.UTF-8 /sbin/yast2 users list")
       lines = ret[:stderr].split "\n"
       @users = []
       lines::each do |s|   
          user = User.new 	
          user.loginName = s.rstrip
          @users << user
       end
    else
       @users = []
       user = User.new 	
       user.error_id = 1
       user.error_string = "no permission"
       @users << user
    end
  end

  def get_user (id)
    if @user
      saveKey = @user.sshkey
    else
      saveKey = nil
    end
    ret = Scr.execute("LANG=en.UTF-8 /sbin/yast2 users show username=#{id}")
     lines = ret[:stderr].split "\n"
     counter = 0
     @user = User.find(:first)
     if @user == nil
       @user = User.new
       @user.save
     end
     lines::each do |s|   
       if counter+1 <= lines.length
         case s
         when "Full Name:"
           @user.fullName = lines[counter+1].strip
         when "List of Groups:"
           @user.groups = lines[counter+1].strip
         when "Default Group:"
           @user.defaultGroup = lines[counter+1].strip
         when "Home Directory:"
           @user.homeDirectory = lines[counter+1].strip
         when "Login Shell:"
           @user.loginShell = lines[counter+1].strip
         when "Login Name:"
           @user.loginName = lines[counter+1].strip
         when "UID:"
           @user.uid = lines[counter+1].strip
         end
       end
       counter += 1
     end
     @user.sshkey = saveKey
     @user.error_id = 0
     @user.error_string = ""
  end

  def createSSH
    if @user.homeDirectory == nil || @user.homeDirectory.length == 0
      saveKey = @user.sshkey
      get_user @user.loginName
      @user.sshkey = saveKey
    end

    ret = Scr.readArg(".target.stat", "#{@user.homeDirectory}/.ssh/authorized_keys")
    if ret.length == 0
      logger.debug "Create: #{@user.homeDirectory}/.ssh/authorized_keys"
      Scr.execute("/bin/mkdir #{@user.homeDirectory}/.ssh")      
      Scr.execute("/bin/chown #{@user.loginName} #{@user.homeDirectory}/.ssh}")      
      Scr.execute("/bin/chmod 755 #{@user.homeDirectory}/.ssh}")
      Scr.execute("/usr/bin/touch #{@user.homeDirectory}/.ssh/authorized_keys")      
      Scr.execute("/bin/chown #{@user.loginName} #{@user.homeDirectory}/.ssh/authorized_keys}")      
      Scr.execute("/bin/chmod 644 #{@user.homeDirectory}/.ssh/authorized_keys}")
    end
    ret =  Scr.execute("echo \"#{@user.sshkey}\"  >> #{@user.homeDirectory}/.ssh/authorized_keys")
    if ret[:exit] != 0
      return false
    else 
      return true
    end
  end

  def udate_user userId
    ok = true

    if @user.sshkey && @user.sshkey.length > 0
      ok = createSSH
    end

    command = "LANG=en.UTF-8 /sbin/yast2 users edit "
    if @user.fullName && @user.fullName.length > 0
      command = command + 'cn="' + @user.fullName + '" '
    end
    if @user.groups && @user.groups.length > 0
      command += "grouplist=#{@user.groups} "
    end
    if @user.defaultGroup && @user.defaultGroup.length > 0
      command += "gid=#{@user.defaultGroup} "
    end
    if @user.homeDirectory && @user.homeDirectory.length > 0
      command += "home=#{@user.homeDirectory} "
    end
    if @user.loginShell && @user.loginShell.length > 0
      command += "shell=#{@user.loginShell} "
    end
    if userId && userId.length > 0
      command += "username=#{userId} "
    end
    if @user.uid && @user.uid.length > 0
      command += "uid=#{@user.uid} "
    end
    if @user.password && @user.password.length > 0
      command += "password=#{@user.password} "
    end
    if @user.ldapPassword && @user.ldapPassword.length > 0
      command += "ldap_password=#{@user.ldapPassword} "
    end
    if @user.newUid && @user.newUid.length > 0
      command += "new_uid=#{@user.newUid} "
    end
    if @user.newLoginName && @user.newLoginName.length > 0
      command += "new_username=#{@user.newLoginName} "
    end
    if @user.type && @user.type.length > 0
      command += "type=#{@user.type} "
    end
    command += " batchmode"
    ret = Scr.execute(command)
    if ret[:exit] != 0
      ok = false
      @user.error_id = ret[:exit]
      @user.error_string = ret[:stderr]
    end
    return ok
  end

  def add_user
    command = "LANG=en.UTF-8 /sbin/yast2 users add "
    if @user.fullName && @user.fullName.length > 0
      command = command + 'cn="' + @user.fullName + '" '
    end
    if @user.groups && @user.groups.length > 0
      command += "grouplist=#{@user.groups} "
    end
    if @user.defaultGroup && @user.defaultGroup.length > 0
      command += "gid=#{@user.defaultGroup} "
    end
    if @user.homeDirectory && @user.homeDirectory.length > 0
      command += "home=#{@user.homeDirectory} "
    end
    if @user.loginShell && @user.loginShell.length > 0
      command += "shell=#{@user.loginShell} "
    end
    if @user.loginName && @user.loginName.length > 0
      command += "username=#{@user.loginName} "
    end
    if @user.uid && @user.uid.length > 0
      command += "uid=#{@user.uid} "
    end
    if @user.password && @user.password.length > 0
      command += "password=#{@user.password} "
    end
    if @user.ldapPassword && @user.ldapPassword.length > 0
      command += "ldap_password=#{@user.ldapPassword} "
    end
    if @user.noHome && @user.noHome = "true"
      command += "no_home "
    end
    if @user.type && @user.type.length > 0
      command += "type=#{@user.type} "
    end
    command += " batchmode"

    ret = Scr.execute(command)

    logger.debug "Command returns: #{ret.inspect}"

    if ret[:exit] == 0
      return true
    else
      @user.error_id = ret[:exit]
      @user.error_string = ret[:stderr]
      return false
    end
  end

  def delete_user
    command = "LANG=en.UTF-8 /sbin/yast2 users delete delete_home "
    if @user.uid && @user.uid.length > 0
      command += "uid=#{@user.uid} "
    end
    if @user.loginName && @user.loginName.length > 0
      command += "username=#{@user.loginName} "
    end
    if @user.ldapPassword && @user.ldapPassword.length > 0
      command += "ldap_password=#{@user.ldapPassword} "
    end
    if @user.type && @user.type.length > 0
      command += "type=#{@user.type} "
    end

    command += " batchmode"

    ret = Scr.execute(command)
    if ret[:exit] == 0
      return true
    else
      @user.error_id = ret[:exit]
      @user.error_string = ret[:stderr]
      return false
    end
  end

#--------------------------------------------------------------------------------
#
# actions
#
#--------------------------------------------------------------------------------

  # GET /users
  # GET /users.xml
  # GET /users.json
  def index
    get_userList

    respond_to do |format|
      format.html { render :xml => @users, :location => "none" } #return xml only
      format.xml  { render :xml => @users, :location => "none" }
      format.json { render :json => @users.to_json, :location => "none" }
    end
  end

  # GET /users/1
  # GET /users/1.xml
  def show
    if permissionCheck( "org.opensuse.yast.webservice.read-user")
       get_user params[:id]
    else
       @user = User.new
       @user.error_id = 1
       @user.error_string = "no permission"
    end       

    respond_to do |format|
      format.html { render :xml => @user, :location => "none" } #return xml only
      format.xml  { render :xml => @user, :location => "none" }
      format.json { render :json => @user.to_json, :location => "none" }
    end
  end

  # GET /users/new
  # GET /users/new.xml
  def new
    @user = User.new
    if !permissionCheck( "org.opensuse.yast.webservice.new-user")
       @user.error_id = 1
       @user.error_string = "no permission"
    end
    respond_to do |format|
      format.html { render :xml => @user, :location => "none" } #return xml only
      format.xml  { render :xml => @user, :location => "none" }
      format.json  { render :json => @user, :location => "none" }
    end
  end

  # GET /users/1/edit
  def edit
    if !permissionCheck( "org.opensuse.yast.webservice.write-user")
       @user = User.new
       @user.error_id = 1
       @user.error_string = "no permission"
    else
       get_user params[:id]
    end
  end

  # POST /users
  # POST /users.xml
  # POST /users.json
  def create
    @user = User.new(params[:user])
    if !permissionCheck( "org.opensuse.yast.webservice.new-user")
       @user.error_id = 1
       @user.error_string = "no permission"
    else
       add_user
    end
    respond_to do |format|
      format.html  { render :xml => @user.to_xml( :root => "user",
                    :dasherize => false), :location => "none" } #return xml only
      format.xml  { render :xml => @user.to_xml( :root => "user",
                    :dasherize => false), :location => "none" }
      format.json  { render :json => @user.to_json, :location => "none" }
    end
  end

  # PUT /users/1
  # PUT /users/1.xml
  def update
    if !permissionCheck( "org.opensuse.yast.webservice.write-user")
       @user = User.new(params[:user])
       @user.error_id = 1
       @user.error_string = "no permission"
    else

       if params[:user] && params[:user][:loginName]
          params[:id] = params[:user][:loginName] #for sync only
       end
       get_user params[:id]
       if @user.update_attributes(params[:user])
          udate_user params[:id]
       else
          @user.error_id = 2
          @user.error_string = "wrong parameter"
       end
    end
    respond_to do |format|
       format.html  { render :xml => @user.to_xml( :root => "user",
                     :dasherize => false), :location => "none" }
       format.xml  { render :xml => @user.to_xml( :root => "user",
                     :dasherize => false), :location => "none" }
       format.json  { render :json => @user.to_json, :location => "none" }
    end
  end

  # DELETE /users/1
  # DELETE /users/1.xml
  # DELETE /users/1.json
  def destroy
    if !permissionCheck( "org.opensuse.yast.webservice.delete-user")
       @user = User.new
       @user.error_id = 1
       @user.error_string = "no permission"
    else
       get_user params[:id]
       @user.destroy
       delete_user
       logger.debug "DELETE: #{@user.inspect}"
    end
    respond_to do |format|
       format.html { render :xml => @user.to_xml( :root => "user",
                     :dasherize => false), :location => "none" } #return xml only
       format.xml  { render :xml => @user.to_xml( :root => "user",
                     :dasherize => false), :location => "none" }
       format.json  { render :json => @user.to_json, :location => "none" }
    end
  end

  # GET /users/1/exportssh
  def exportssh
    if (!permissionCheck( "org.opensuse.yast.webservice.write-user") and
        !permissionCheck( "org.opensuse.yast.webservice.write-user-sshkey"))
       @user = User.new
       @user.error_id = 1
       @user.error_string = "no permission"
    else
       get_user params[:id]
    end
    logger.debug "exportssh: #{@user.inspect}"
    respond_to do |format|
      format.html { render :xml => @user, :location => "none" } #return xml only
      format.xml  { render :xml => @user, :location => "none" }
      format.json { render :json => @user, :location => "none" }
    end
  end


  # GET/PUT /users/1/<single-value>
  def singleValue
    if request.get?
      # GET
      @user = User.new
      @retUser = User.new
      get_user params[:users_id]
      #initialize not needed stuff (perhaps no permissions available)
      case params[:id]
        when "defaultGroup"
          if ( permissionCheck( "org.opensuse.yast.webservice.read-user") or
               permissionCheck( "org.opensuse.yast.webservice.read-user-defaultgroup"))
             @retUser.defaultGroup = @user.defaultGroup
          else
             @retUser.error_id = 1
             @retUser.error_string = "no permission"
          end         
        when "fullName"
          if ( permissionCheck( "org.opensuse.yast.webservice.read-user") or
               permissionCheck( "org.opensuse.yast.webservice.read-user-fullname"))
             @retUser.fullName = @user.fullName
          else
             @retUser.error_id = 1
             @retUser.error_string = "no permission"
          end         
        when "groups"
          if ( permissionCheck( "org.opensuse.yast.webservice.read-user") or
               permissionCheck( "org.opensuse.yast.webservice.read-user-groups")) then
             @retUser.groups = @user.groups
          else
             @retUser.error_id = 1
             @retUser.error_string = "no permission"
          end         
        when "homeDirectory"
          if ( permissionCheck( "org.opensuse.yast.webservice.read-user") or
               permissionCheck( "org.opensuse.yast.webservice.read-user-homedirectory")) then
             @retUser.homeDirectory = @user.homeDirectory
          else
             @retUser.error_id = 1
             @retUser.error_string = "no permission"
          end         
        when "loginName"
          if ( permissionCheck( "org.opensuse.yast.webservice.read-user") or
               permissionCheck( "org.opensuse.yast.webservice.read-user-loginname")) then
             @retUser.loginName = @user.loginName
          else
             @retUser.error_id = 1
             @retUser.error_string = "no permission"
          end         
        when "loginShell"
          if ( permissionCheck( "org.opensuse.yast.webservice.read-user") or
               permissionCheck( "org.opensuse.yast.webservice.read-user-loginshell")) then
             @retUser.loginShell = @user.loginShell
          else
             @retUser.error_id = 1
             @retUser.error_string = "no permission"
          end         
        when "uid"
          if ( permissionCheck( "org.opensuse.yast.webservice.read-user") or
               permissionCheck( "org.opensuse.yast.webservice.read-user-uid")) then
             @retUser.uid = @user.uid
          else
             @retUser.error_id = 1
             @retUser.error_string = "no permission"
          end         
      end
      @user = @retUser
      respond_to do |format|
        format.xml do
          render :xml => @user.to_xml( :root => "users",
            :dasherize => false ), :location => "none"
        end
        format.json do
	  render :json => @user.to_json, :location => "none"
        end
        format.html do
          render :xml => @user.to_xml( :root => "users",
            :dasherize => false ), :location => "none" #return xml only
        end
      end      
    else
      #PUT
      respond_to do |format|
        @setUser = User.new
        @user = User.new
        if @setUser.update_attributes(params[:user])
          logger.debug "UPDATED: #{@setUser.inspect}"
          ok = true
          #setting which are clear
          @user.loginName = params[:users_id]
          @user.ldapPassword = @setUser.ldapPassword
          exportSSH = false
          case params[:id]
            when "defaultGroup"
              if ( permissionCheck( "org.opensuse.yast.webservice.write-user") or
                  permissionCheck( "org.opensuse.yast.webservice.write-user-defaultgroup")) then
                 @user.defaultGroup = @setUser.defaultGroup
              else
                 @user.error_id = 1
                 @user.error_string = "no permission"
              end         
            when "fullName"
              if ( permissionCheck( "org.opensuse.yast.webservice.write-user") or
                   permissionCheck( "org.opensuse.yast.webservice.write-user-fullname")) then
                 @user.fullName = @setUser.fullName
              else
                 @user.error_id = 1
                 @user.error_string = "no permission"
              end         
            when "groups"
              if ( permissionCheck( "org.opensuse.yast.webservice.write-user") or
                   permissionCheck( "org.opensuse.yast.webservice.write-user-groups")) then
                 @user.groups = @setUser.groups
              else
                 @user.error_id = 1
                 @user.error_string = "no permission"
              end         
            when "homeDirectory"
              if ( permissionCheck( "org.opensuse.yast.webservice.write-user") or
                   permissionCheck( "org.opensuse.yast.webservice.write-user-homedirectory")) then
                 @user.homeDirectory = @setUser.homeDirectory
              else
                 @user.error_id = 1
                 @user.error_string = "no permission"
              end         
            when "newLoginName"
              if ( permissionCheck( "org.opensuse.yast.webservice.write-user") or
                   permissionCheck( "org.opensuse.yast.webservice.write-user-loginname")) then
                 @user.newLoginName = @setUser.newLoginName
              else
                 @user..error_id = 1
                 @user.error_string = "no permission"
              end         
            when "loginShell"
              if ( permissionCheck( "org.opensuse.yast.webservice.write-user") or
                   permissionCheck( "org.opensuse.yast.webservice.write-user-loginshell")) then
                 @user.loginShell = @setUser.loginShell
              else
                 @user.error_id = 1
                 @user.error_string = "no permission"
              end         
            when "newUid"
              if ( permissionCheck( "org.opensuse.yast.webservice.write-user") or
                   permissionCheck( "org.opensuse.yast.webservice.write-user-uid")) then
                 @user.newUid = @setUser.newUid
              else
                 @user.error_id = 1
                 @user.error_string = "no permission"
              end         
            when "password"
              if ( permissionCheck( "org.opensuse.yast.webservice.write-user") or
                   permissionCheck( "org.opensuse.yast.webservice.write-user-password")) then
                 @user.password = @setUser.password
              else
                 @user.error_id = 1
                 @user.error_string = "no permission"
              end         
            when "type"
              if ( permissionCheck( "org.opensuse.yast.webservice.write-user") or
                   permissionCheck( "org.opensuse.yast.webservice.write-user-type")) then
                 @user.type = @setUser.type
              else
                 @user.error_id = 1
                 @user.error_string = "no permission"
              end         
            when "sshkey"
              if ( permissionCheck( "org.opensuse.yast.webservice.write-user")  or
                   permissionCheck( "org.opensuse.yast.webservice.write-user-sshkey")) then
                 @user.sshkey = @setUser.sshkey
                 exportSSH = true
              else
                 @user.error_id = 1
                 @user.error_string = "no permission"
              end         
            else
              logger.error "Wrong ID: #{params[:id]}"
              @user.error_id = 2
              @user.error_string = "Wrong ID: #{params[:id]}"
              ok = false
          end
          if ok
            if exportSSH
              saveUser = @user
              ok = createSSH #reads @user again
              @user = saveUser
            else
              ok = udate_user params[:users_id]
            end
          end
        else
           @user.error_id = 2
           @user.error_string = "format or internal error"
        end

        format.html do
            render :xml => @user.to_xml( :root => "user",
                     :dasherize => false ), :location => "none" #return xml only
        end
        format.xml do
            render :xml => @user.to_xml( :root => "user",
                     :dasherize => false ), :location => "none"
        end
        format.json do
           render :json => @user.to_json, :location => "none"
        end
      end
    end
  end


end


