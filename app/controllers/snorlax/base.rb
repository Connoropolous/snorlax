module Snorlax
  class Base < ::ApplicationController

    def self.snorlax_used_rest!(controller)
      controller.class_eval do
        rescue_from(CanCan::AccessDenied)                    { |e| respond_with_standard_error e, 403 }
        rescue_from(ActionController::UnpermittedParameters) { |e| respond_with_standard_error e, 400 }
        rescue_from(ActionController::ParameterMissing)      { |e| respond_with_standard_error e, 400 }
        rescue_from(ActiveRecord::RecordNotFound)            { |e| respond_with_standard_error e, 404 }

        def show
          respond_with_resource
        end

        def index
          instantiate_collection
          respond_with_collection
        end

        def create
          instantiate_resouce
          create_action
          respond_with_resource
        end

        def create_action
          resource.save
        end

        def update
          load_resource
          update_action
          respond_with_resource
        end

        def update_action
          resource.update(resource_params)
        end

        def destroy
          load_resource
          destroy_action
          render json: {success: 'success'}
        end

        def destroy_action
          resource.destroy
        end

        private

        def collection
          instance_variable_get :"@#{resource_plural}"
        end

        def resource
          instance_variable_get :"@#{resource_name}"
        end

        def resource=(value)
          instance_variable_set :"@#{resource_name}", value
        end

        def collection=(value)
          instance_variable_set :"@#{resource_name.pluralize}", value
        end

        def instantiate_resouce
          self.resource = resource_class.new(resource_params)
        end

        def instantiate_collection(timeframe_collection: true, page_collection: true)
          collection = accessible_records
          collection = yield collection                if block_given?
          collection = timeframe_collection collection if timeframe_collection
          collection = page_collection collection      if page_collection
          self.collection = collection.to_a
        end

        def timeframe_collection(collection)
          if resource_class.try(:has_timeframe?) && (params[:since] || params[:until])
            parse_date_parameters # I feel like Rails should do this for me..
            collection.within(params[:since], params[:until], params[:timeframe_for])
          else
            collection
          end
        end

        def parse_date_parameters
          %w(since until).each { |field| params[field] = DateTime.parse(params[field].to_s) if params[field] }
        end

        def page_collection(collection)
          collection.offset(params[:from]).limit(params[:per] || default_page_size)
        end

        def accessible_records
          if current_user.is_logged_in?
            visible_records
          else
            public_records
          end
        end

        def visible_records
          raise NotImplementedError.new
        end

        def public_records
          raise NotImplementedError.new
        end

        def default_page_size
          50
        end

        def load_resource
          self.resource = resource_class.find(params[:id])
        end

        def resource_params
          permitted_params.send resource_name
        end

        def resource_symbol
          resource_name.to_sym
        end

        def resource_name
          controller_name.singularize
        end

        def resource_class
          resource_name.camelize.constantize
        end

        def resource_plural
          controller_name
        end

        def resource_serializer
          "#{resource_name}_serializer".camelize.constantize
        end

        def respond_with_resource(scope: default_scope, serializer: resource_serializer, root: serializer_root)
          if resource.errors.empty?
            respond_with_collection(resources: [resource], scope: scope, serializer: serializer, root: root)
          else
            respond_with_errors
          end
        end

        def respond_with_collection(resources: collection, scope: default_scope, serializer: resource_serializer, root: serializer_root)
          render json: resources, scope: scope, each_serializer: serializer, root: root
        end

        def respond_with_standard_error(error, status)
          render json: {exception: error.class.to_s}, root: false, status: status
        end

        def respond_with_errors
          render json: {errors: resource.errors.as_json}, root: false, status: 422
        end

        def serializer_root
          controller_name
        end

        def default_scope
          {}
        end
      end
    end

    snorlax_used_rest!(self)

  end
end
