class RotisseriePostsController < ApplicationController
  # GET /rotisserie_posts
  # GET /rotisserie_posts.xml
  def index
    @rotisserie_posts = RotisseriePost.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @rotisserie_posts }
    end
  end

  # GET /rotisserie_posts/1
  # GET /rotisserie_posts/1.xml
  def show
    @rotisserie_post = RotisseriePost.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @rotisserie_post }
    end
  end

  # GET /rotisserie_posts/new
  # GET /rotisserie_posts/new.xml
  def new
    @rotisserie_post = RotisseriePost.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @rotisserie_post }
    end
  end

  # GET /rotisserie_posts/1/edit
  def edit
    @rotisserie_post = RotisseriePost.find(params[:id])
  end

  # POST /rotisserie_posts
  # POST /rotisserie_posts.xml
  def create
    @rotisserie_post = RotisseriePost.new(params[:rotisserie_post])

    respond_to do |format|
      if @rotisserie_post.save
        @rotisserie_post.accepts_role!(:owner, current_user)

        flash[:notice] = 'RotisseriePost was successfully created.'
        format.js {render :text => nil}
        format.html { redirect_to(@rotisserie_post) }
        format.xml  { render :xml => @rotisserie_post, :status => :created, :location => @rotisserie_post }
      else
        @error_output = "<div class='error ui-corner-all'>"
         @rotisserie_post.errors.each{ |attr,msg|
           @error_output += "#{attr} #{msg}<br />"
         }
        @error_output += "</div>"

        format.js {render :text => @error_output, :status => :unprocessable_entity}
        format.html { render :action => "new" }
        format.xml  { render :xml => @rotisserie_post.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /rotisserie_posts/1
  # PUT /rotisserie_posts/1.xml
  def update
    @rotisserie_post = RotisseriePost.find(params[:id])

    respond_to do |format|
      if @rotisserie_post.update_attributes(params[:rotisserie_post])
        flash[:notice] = 'RotisseriePost was successfully updated.'
        format.js {render :text => nil}
        format.html { redirect_to(@rotisserie_post) }
        format.xml  { head :ok }
      else
        error_output = "<div class='error ui-corner-all'>"
         @rotisserie_post.errors.each{ |attr,msg|
           error_output += "#{attr} #{msg}<br />"
         }
        error_output += "</div>"

        format.js { render :text => error_output, :layout => false  }
        format.html { render :action => "edit" }
        format.xml  { render :xml => @rotisserie_post.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /rotisserie_posts/1
  # DELETE /rotisserie_posts/1.xml
  def destroy
    @rotisserie_post = RotisseriePost.find(params[:id])
    @rotisserie_post.destroy

    respond_to do |format|
      format.html { redirect_to(rotisserie_posts_url) }
      format.xml  { head :ok }
    end
  end

  def block
    respond_to do |format|
      format.html {
        render :partial => 'rotisserie_posts_block', :locals => {:container_id => params[:container_id]},
        :layout => false
      }
      format.xml  { head :ok }
    end
  end

end
