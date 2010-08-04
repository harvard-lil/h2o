class RotisserieDiscussionsController < ApplicationController

  before_filter :require_user, :except => [:metadata]

  # GET /rotisserie_discussions
  # GET /rotisserie_discussions.xml
  def index
    @rotisserie_discussions = RotisserieDiscussion.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @rotisserie_discussions }
    end
  end

  # GET /rotisserie_discussions/1
  # GET /rotisserie_discussions/1.xml
  def show
    @rotisserie_discussion = RotisserieDiscussion.find(params[:id])
    @rotisserie_instance = @rotisserie_discussion.rotisserie_instance

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @rotisserie_discussion }
    end
  end

  # GET /rotisserie_discussions/new
  # GET /rotisserie_discussions/new.xml
  def new
    @rotisserie_discussion = RotisserieDiscussion.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @rotisserie_discussion }
    end
  end

  # GET /rotisserie_discussions/1/edit
  def edit
    @rotisserie_discussion = RotisserieDiscussion.find(params[:id])
  end

  # POST /rotisserie_discussions
  # POST /rotisserie_discussions.xml
  def create
    start_date = params[:start_date]
    start_time = params[:blankobject]["start_time(4i)"] + ":" + params[:blankobject]["start_time(5i)"]

    full_date = (start_date + " " + start_time)
    rotisserie_params = params[:rotisserie_discussion]

    rotisserie_params["start_date"] = full_date

    @rotisserie_discussion = RotisserieDiscussion.new(rotisserie_params)

    respond_to do |format|
      if @rotisserie_discussion.save
        @rotisserie_discussion.accepts_role!(:owner, current_user)
        #@rotisserie_discussion.accepts_role!(:user, current_user)

        flash[:notice] = 'RotisserieDiscussion was successfully created.'
        format.js {render :text => nil}
        format.html { redirect_to(@rotisserie_discussion) }
        format.xml  { render :xml => @rotisserie_discussion, :status => :created, :location => @rotisserie_discussion }
      else
        @error_output = "<div class='error ui-corner-all'>"
         @rotisserie_discussion.errors.each{ |attr,msg|
           @error_output += "#{attr} #{msg}<br />"
         }
        @error_output += "</div>"
        
        format.js {render :text => @error_output, :status => :unprocessable_entity}
        format.html { render :action => "new" }
        format.xml  { render :xml => @rotisserie_discussion.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /rotisserie_discussions/1
  # PUT /rotisserie_discussions/1.xml
  def update
    @rotisserie_discussion = RotisserieDiscussion.find(params[:id])

    start_date = params[:start_date]
    start_time = params[:blankobject]["start_time(4i)"] + ":" + params[:blankobject]["start_time(5i)"]

    full_date = (start_date + " " + start_time)
    rotisserie_params = params[:rotisserie_discussion]

    rotisserie_params["start_date"] = full_date

    respond_to do |format|
      if @rotisserie_discussion.update_attributes(rotisserie_params)
        flash[:notice] = 'RotisserieDiscussion was successfully updated.'
        format.js {render :text => nil}
        format.html { redirect_to(@rotisserie_discussion) }
        format.xml  { head :ok }
      else
        error_output = "<div class='error ui-corner-all'>"
         @rotisserie_discussion.errors.each{ |attr,msg|
           error_output += "#{attr} #{msg}<br />"
         }
        error_output += "</div>"

        format.js { render :text => error_output, :layout => false  }
        format.html { render :action => "edit" }
        format.xml  { render :xml => @rotisserie_discussion.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /rotisserie_discussions/1
  # DELETE /rotisserie_discussions/1.xml
  def destroy
    @rotisserie_discussion = RotisserieDiscussion.find(params[:id])
    @rotisserie_discussion.destroy

    respond_to do |format|
      format.js {render :text => nil}
      format.html { redirect_to(rotisserie_discussions_url) }
      format.xml  { head :ok }
    end
  end

  def block
    respond_to do |format|
      format.html {
        render :partial => 'rotisserie_discussions_block', :locals => {:container_id => params[:container_id]},
        :layout => false
      }
      format.xml  { head :ok }
    end
  end

  def metadata
    @rotisserie_discussion = RotisserieDiscussion.find(params[:id])

    @rotisserie_discussion[:object_type] = @rotisserie_discussion.class.to_s
    @rotisserie_discussion[:child_object_name] = 'rotisserie_post'
    @rotisserie_discussion[:child_object_plural] = 'rotisserie_posts'
    @rotisserie_discussion[:child_object_count] = @rotisserie_discussion.rotisserie_posts.length
    @rotisserie_discussion[:child_object_type] = 'RotisseriePost'
    @rotisserie_discussion[:child_object_ids] = @rotisserie_discussion.rotisserie_posts.collect(&:id).compact.join(',')
    @rotisserie_discussion[:title] = @rotisserie_discussion.output_text
    render :xml => @rotisserie_discussion.to_xml(:skip_types => true)
  end
  
  def add_member
    @rotisserie_discussion = RotisserieDiscussion.find(params[:id])
    @rotisserie_discussion.accepts_role!(:user, current_user)
    @rotisserie_discussion.rotisserie_instance.accepts_role!(:user, current_user)
    
    respond_to do |format|
      format.html { redirect_to(rotisserie_discussion_path(@rotisserie_discussion)) }
      format.xml  { head :ok }
    end
  end

  def activate
    RotisserieDiscussion.find(params[:id]).activate_rotisserie

    respond_to do |format|
      format.js {render :text => nil}
    end
  end

  def changestart
    return_hash = Hash.new
    discussion = RotisserieDiscussion.find(params[:id])
    discussion.change_date(h(params[:dayvalue]).to_i)
    return_hash[:start_date] = discussion.start_date.to_s
    return_hash[:round] = discussion.current_round

    respond_to do |format|
      format.js {render :json => return_hash.to_json}
    end
  end

  def notify
    discussion = RotisserieDiscussion.find(h(params[:id]).to_i)
 
    discussion.send_all_notifications

    respond_to do |format|
      format.js {render :text => nil}
    end
  end



end
