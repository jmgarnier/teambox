# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  helper :all # include all helpers, all the time
  protect_from_forgery # See ActionController::RequestForgeryProtection for details
  rescue_from ActiveRecord::RecordNotFound, :with => :show_errors
  
  include AuthenticatedSystem
  include BannerSystem
  filter_parameter_logging :password

  before_filter :rss_token, 
                :confirmed_user?, 
                :load_project, 
                :login_required, 
                :set_locale, 
                :touch_user, 
                :belongs_to_project?, 
                :set_page_title,
                :set_client
  
  private

    def check_permissions
      unless @current_project.editable?(current_user)
        render :text => "You don't have permission to edit/update/delete within \"#{@current_project.name}\" project", :status => :forbidden
      end
    end
    
    def show_errors
      render :partial => 'shared/record_not_found', :layout => 'application'
    end
    
    def confirmed_user?
      if current_user and not current_user.is_active?
        flash[:error] = "You need to activate your account first"
        redirect_to unconfirmed_email_user_path(current_user)
      end
    end
    
    def rss_token
      unless params[:rss_token].nil? or params[:format] != 'rss'
        user = User.find_by_rss_token(params[:rss_token])
        set_current_user user if user
      end
    end

    def belongs_to_project?
      if @current_project && current_user
        unless Person.exists?(:project_id => @current_project.id, :user_id => current_user.id)
          current_user.remove_recent_project(@current_project)
          render :text => "You don't have permission to view this project", :status => :forbidden
        end
      end
    end
    
    def load_project
      project_id ||= params[:project_id]
      project_id ||= params[:id]
      
      if project_id
        @current_project = Project.find_by_permalink(project_id)
        
        if @current_project
          if current_user && !@current_project.archived?
            current_user.add_recent_project(@current_project)
          end
        else        
          flash[:error] = "The project <i>#{h(project_id)}</i> doesn't exist."
          redirect_to projects_path, :status => 301
        end
      end
    end
    
    def set_locale
      # if this is nil then I18n.default_locale will be used
      I18n.locale = logged_in? ? current_user.language : 'en'
    end
    
    def touch_user
      current_user.touch if logged_in?
    end

    def set_page_title
      location_name = "#{params[:action]}_#{params[:controller]}"
      translate_location_name = t("page_title.#{location_name}")

      if params.has_key?(:id) && (location_name == 'show_projects' || 'edit_projects')
        #### I dont know why but this is breaking
        ##        
        #project_name = Project.find(params[:id],:select => 'name').name #Not working for some reason - .grab_name(params[:id])
        #@page_title = "&rarr; #{project_name} &rarr; #{translate_location_name}"
      elsif params.has_key?(:project_id)
        project_name = Project.grab_name_by_permalink(params[:project_id])
        name = nil
        case location_name
          when 'show_tasks'
            name = Task.grab_name(params[:id])
          when 'show_task_lists'
            name = TaskList.grab_name(params[:id])
          when 'show_conversations'
            name = Conversations.grab_name(params[:id])
        end  
        @page_title = "#{project_name} &rarr; #{ name ? name : translate_location_name }"
      else
        name = nil
        user_name = nil
        case location_name
          when 'edit_users'
            user_name = current_user.name
          when 'show_users'
            user_name = current_user.name            
        end    
        @page_title = "#{ "#{user_name} &rarr;" if user_name } #{translate_location_name}"
      end    
    end

    MobileClients = /(iPhone|iPod|Android|Opera mini|Blackberry|Palm|Windows CE|Opera mobi|iemobile)/i

    def set_client
      mobile =   request.env["HTTP_USER_AGENT"] && request.env["HTTP_USER_AGENT"][MobileClients]
      mobile ||= request.env["HTTP_PROFILE"] || request.env["HTTP_X_WAP_PROFILE"]
      if mobile
        request.format = :m
      end
    end
    
    def split_events_by_date(events, start_date=nil)
      start_date ||= Date.today.monday.to_date
      return [] if events.empty?
      split_events = Array.new(14)
      events.each do |event|
        if (event.due_on - start_date) >= 0
          split_events[(event.due_on - start_date)] ||= []
          split_events[(event.due_on - start_date)] << event
        end
      end
      return split_events
    end
    
    # http://www.coffeepowered.net/2009/02/16/powerful-easy-dry-multi-format-rest-apis-part-2/
    def render(opts = nil, extra_options = {}, &block)
    	if opts && opts.is_a?(Hash) then
    		if opts[:to_yaml] or opts[:as_yaml] then
    			headers["Content-Type"] = "text/plain;"
    			text = nil
    			if opts[:as_yaml] then
    				text = Hash.from_xml(opts[:as_yaml]).to_yaml
    			else
    				text = Hash.from_xml(render_to_string(:template => opts[:to_yaml], :layout => false)).to_yaml
    			end
    			super :text => text, :layout => false
    		elsif opts[:to_json] or opts[:as_json] then
    			content = nil
    			if opts[:to_json] then
    				content = Hash.from_xml(render_to_string(:template => opts[:to_json], :layout => false)).to_json
    			elsif opts[:as_json] then
    				content = Hash.from_xml(opts[:as_json]).to_json
    			end
    			cbparam = params[:callback] || params[:jsonp]
    			content = "#{cbparam}(#{content})" unless cbparam.blank?
    			super :json => content, :layout => false
    		else
    			super(opts, extra_options, &block)
    		end
    	else
    		super(opts, extra_options, &block)
    	end
    end
    
end
