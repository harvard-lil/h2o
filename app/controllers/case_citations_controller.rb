class CaseCitationsController < ApplicationController
  # GET /case_citations
  # GET /case_citations.xml
  def index
    @case_citations = CaseCitation.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @case_citations }
    end
  end

  # GET /case_citations/1
  # GET /case_citations/1.xml
  def show
    @case_citation = CaseCitation.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @case_citation }
    end
  end

  # GET /case_citations/new
  # GET /case_citations/new.xml
  def new
    @case_citation = CaseCitation.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @case_citation }
    end
  end

  # GET /case_citations/1/edit
  def edit
    @case_citation = CaseCitation.find(params[:id])
  end

  # POST /case_citations
  # POST /case_citations.xml
  def create
    @case_citation = CaseCitation.new(params[:case_citation])

    respond_to do |format|
      if @case_citation.save
        flash[:notice] = 'CaseCitation was successfully created.'
        format.html { redirect_to(@case_citation) }
        format.xml  { render :xml => @case_citation, :status => :created, :location => @case_citation }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @case_citation.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /case_citations/1
  # PUT /case_citations/1.xml
  def update
    @case_citation = CaseCitation.find(params[:id])

    respond_to do |format|
      if @case_citation.update_attributes(params[:case_citation])
        flash[:notice] = 'CaseCitation was successfully updated.'
        format.html { redirect_to(@case_citation) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @case_citation.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /case_citations/1
  # DELETE /case_citations/1.xml
  def destroy
    @case_citation = CaseCitation.find(params[:id])
    @case_citation.destroy

    respond_to do |format|
      format.html { redirect_to(case_citations_url) }
      format.xml  { head :ok }
    end
  end
end
