class TasksController < ApplicationController
  before_filter :load_task, :except => [:new, :create, :reorder]
  before_filter :load_task_list, :only => [:new, :create]
  before_filter :set_page_title

  def show
    respond_to do |f|
      f.html
      f.js {
        @show_part = params[:part]
        render :template => 'tasks/reload'
      }
      f.xml  { render :xml     => @task.to_xml }
      f.json { render :as_json => @task.to_xml }
      f.yaml { render :as_yaml => @task.to_xml }
    end
  end

  def new
    @task = @task_list.tasks.new
  end

  def create
    @task = @task_list.tasks.create_by_user(current_user, params[:task])
    
    respond_to do |f|
      f.html {
        if request.xhr?
          render :partial => 'tasks/task', :locals => {
            :project => @current_project,
            :task_list => @task_list,
            :task => @task,
            :editable => true
          }
        else
          if @task.new_record?
            render :new
          else
            redirect_to_task
          end
        end
      }
    end
  end

  def edit
    respond_to do |f|
      f.html
      f.js
    end
  end

  def update
    @task.updating_user = current_user
    success = @task.update_attributes params[:task]
    
    respond_to do |f|
      f.html {
        if request.xhr? or iframe?
          comment = @task.comments.last(:order => 'id')
          render :partial => 'comments/comment',
            :locals => { :comment => comment, :threaded => true }
        else
          if success
            redirect_to_task
          else
            render :edit
          end
        end
      }
      f.js {
        if params[:task][:name]
          head :ok
        end
      }
    end
  end

  def destroy
    @task.destroy

    respond_to do |f|
      f.html {
        flash[:success] = t('deleted.task', :name => @task.to_s)
        redirect_to [@current_project, @task_list]
      }
      f.js
      handle_api_success(f, @task)
    end
  end

  def reorder
    @task = @current_project.tasks.find params[:id]
    target_task_list = @current_project.task_lists.find params[:task_list_id]

    if @task.task_list != target_task_list
      @task.remove_from_list
      @task.task_list = target_task_list
    end
    
    @task.insert_at params[:position].to_i
    
    head :ok
  end

  def watch
    @task.add_watcher(current_user)
    respond_to do |f|
      f.js
    end
  end

  def unwatch
    @task.remove_watcher(current_user)
    respond_to do |f|
      f.js
    end
  end

  private

    def load_task_list
      @task_list = @current_project.task_lists.find params[:task_list_id] if params[:task_list_id]
    end

    def load_task
      parent = load_task_list ? @task_list : @current_project
      @task = parent.tasks.find params[:id]
    end
    
    def redirect_to_task
      redirect_to [@current_project, @task_list || @task.task_list, @task]
    end
end