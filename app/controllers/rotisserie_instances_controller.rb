class RotisserieInstancesController < ApplicationController

  before_filter :require_user, :load_single_resource
  
  access_control do
    allow logged_in, :to => [:index, :new, :create]
    allow :admin
    allow :owner, :of => :rotisserie_instance
    allow :editor, :of => :rotisserie_instance, :to => [:index, :show, :edit, :update]
    allow :user, :of => :rotisserie_instance, :to => [:index, :show]
  end

  # GET /rotisserie_instances
  # GET /rotisserie_instances.xml
  def index
    #@rotisserie_instances = RotisserieInstance.all

    respond_to do |format|
      format.html # index.html.erb
      #format.xml  { render :xml => @rotisserie_instances }
    end
  end

  # GET /rotisserie_instances/1
  # GET /rotisserie_instances/1.xml
  def show
    @rotisserie_instance = RotisserieInstance.find(params[:id])
    @tid = params[:tid]
    @notification_invite = NotificationInvite.first(:conditions => {:tid => @tid, :accepted => false}) unless @tid.blank?

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @rotisserie_instance }
    end
  end

  # GET /rotisserie_instances/new
  # GET /rotisserie_instances/new.xml
  def new
    @rotisserie_instance = RotisserieInstance.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @rotisserie_instance }
    end
  end

  # GET /rotisserie_instances/1/edit
  def edit
    @rotisserie_instance = RotisserieInstance.find(params[:id])
  end

  # POST /rotisserie_instances
  # POST /rotisserie_instances.xml
  def create
    @rotisserie_instance = RotisserieInstance.new(params[:rotisserie_instance])
    

    respond_to do |format|
      if @rotisserie_instance.save

        # If save then assign role as owner to object
        @rotisserie_instance.accepts_role!(:owner, current_user)

        flash[:notice] = 'RotisserieInstance was successfully created.'
        format.js {render :text => nil}
        format.html { redirect_to(@rotisserie_instance) }
        format.xml  { render :xml => @rotisserie_instance, :status => :created, :location => @rotisserie_instance }
      else
        @error_output = "<div class='error ui-corner-all'>"
        @rotisserie_instance.errors.each{ |attr,msg|
          @error_output += "#{attr} #{msg}<br />"
        }
        @error_output += "</div>"
        
        format.js {render :text => @error_output, :status => :unprocessable_entity}
        format.html { render :action => "new"}
        format.xml  { render :xml => @rotisserie_instance.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /rotisserie_instances/1
  # PUT /rotisserie_instances/1.xml
  def update
    @rotisserie_instance = RotisserieInstance.find(params[:id])

    respond_to do |format|
      if @rotisserie_instance.update_attributes(params[:rotisserie_instance])
        flash[:notice] = 'RotisserieInstance was successfully updated.'
        format.js {render :text => nil}
        format.html { redirect_to(@rotisserie_instance) }
        format.xml  { head :ok }
      else
        error_output = "<div class='error ui-corner-all'>"
        @rotisserie_instance.errors.each{ |attr,msg|
          error_output += "#{attr} #{msg}<br />"
        }
        error_output += "</div>"
        
        format.js { render :text => error_output, :layout => false  }
        format.html { render :action => "edit" }
        format.xml  { render :xml => @rotisserie_instance.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /rotisserie_instances/1
  # DELETE /rotisserie_instances/1.xml
  def destroy
    @rotisserie_instance = RotisserieInstance.find(params[:id])
    @rotisserie_instance.destroy

    respond_to do |format|
      format.js {render :text => nil}
      format.html { redirect_to(rotisserie_instances_url) }
      format.xml  { head :ok }
    end
  end

  def block
    respond_to do |format|
      format.html { 
        render :partial => 'rotisserie_instances_block',
        :layout => false
      }
      format.xml  { head :ok }
    end
  end
  
  def add_member
    @rotisserie_instance = RotisserieInstance.find(params[:id])
    @rotisserie_instance.accepts_role!(:user, current_user)
    
    @tid = params[:tid]
    @notification_invite = NotificationInvite.first(:conditions => {:tid => @tid, :accepted => false}) unless @tid.blank?

    @notification_invite.update_attributes({:accepted => true}) unless @notification_invite.blank?

    respond_to do |format|
      format.html { redirect_to(polymorphic_path(@rotisserie_instance)) }
      format.xml  { head :ok }
    end
  end

  def invite
    @rotisserie_instance = RotisserieInstance.find(params[:id])
  end

  def validate_email_csv
    return_hash = Hash.new
    email_list = params["csv_string"]
    email_array = email_list.split(",").collect(&:strip)
    return_hash["good_array"] = Array.new
    return_hash["bad_array"] = Array.new

    email_array.each do |email_address|
      (/^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i =~ email_address).present? ? return_hash["good_array"] << email_address : return_hash["bad_array"] << email_address unless email_address.blank?
    end

    return_hash["good_array"].uniq!
    return_hash["bad_array"].uniq!

    respond_to do |format|
      format.js {render :json => return_hash.to_json}
    end
  end

  def display_validation
    good_array = params[:good_array]
    bad_array = params[:bad_array]

    respond_to do |format|
      format.html {
        render :partial => 'email_validation',
        :layout => false, :locals => {:good_array => good_array, :bad_array => bad_array}
      }
      format.xml  { head :ok }
    end
  end

  def queue_email
    return_hash = Hash.new
    email_addresses = params[:good_addresses]
    container_id = params[:container_id]
    container_type = params[:container_type]

    email_addresses.each do |email_address|
      NotificationInvite.create(:user_id => current_user.id,
        :email_address => email_address,
        :resource_id => container_id,
        :resource_type => container_type,
        :tid => ActiveSupport::SecureRandom.hex(13)
      ) unless container_id.blank?
    end

    respond_to do |format|
      format.js {render :json => return_hash.to_json}
    end
    
  end

end
