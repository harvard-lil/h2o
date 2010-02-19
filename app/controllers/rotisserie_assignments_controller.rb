class RotisserieAssignmentsController < ApplicationController
  # GET /rotisserie_assignments
  # GET /rotisserie_assignments.xml
  def index
    @rotisserie_assignments = RotisserieAssignment.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @rotisserie_assignments }
    end
  end

  # GET /rotisserie_assignments/1
  # GET /rotisserie_assignments/1.xml
  def show
    @rotisserie_assignment = RotisserieAssignment.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @rotisserie_assignment }
    end
  end

  # GET /rotisserie_assignments/new
  # GET /rotisserie_assignments/new.xml
  def new
    @rotisserie_assignment = RotisserieAssignment.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @rotisserie_assignment }
    end
  end

  # GET /rotisserie_assignments/1/edit
  def edit
    @rotisserie_assignment = RotisserieAssignment.find(params[:id])
  end

  # POST /rotisserie_assignments
  # POST /rotisserie_assignments.xml
  def create
    @rotisserie_assignment = RotisserieAssignment.new(params[:rotisserie_assignment])

    respond_to do |format|
      if @rotisserie_assignment.save
        flash[:notice] = 'RotisserieAssignment was successfully created.'
        format.html { redirect_to(@rotisserie_assignment) }
        format.xml  { render :xml => @rotisserie_assignment, :status => :created, :location => @rotisserie_assignment }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @rotisserie_assignment.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /rotisserie_assignments/1
  # PUT /rotisserie_assignments/1.xml
  def update
    @rotisserie_assignment = RotisserieAssignment.find(params[:id])

    respond_to do |format|
      if @rotisserie_assignment.update_attributes(params[:rotisserie_assignment])
        flash[:notice] = 'RotisserieAssignment was successfully updated.'
        format.html { redirect_to(@rotisserie_assignment) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @rotisserie_assignment.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /rotisserie_assignments/1
  # DELETE /rotisserie_assignments/1.xml
  def destroy
    @rotisserie_assignment = RotisserieAssignment.find(params[:id])
    @rotisserie_assignment.destroy

    respond_to do |format|
      format.html { redirect_to(rotisserie_assignments_url) }
      format.xml  { head :ok }
    end
  end
end
