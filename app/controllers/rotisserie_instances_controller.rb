class RotisserieInstancesController < ApplicationController
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
    @rotisserie_discussions = 

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

end
