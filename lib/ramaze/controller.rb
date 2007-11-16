#          Copyright (c) 2006 Michael Fellinger m.fellinger@gmail.com
# All files in this distribution are subject to the terms of the Ruby license.

require 'ramaze/helper'
require 'ramaze/template'
require 'ramaze/action'

require 'ramaze/controller/resolve'
require 'ramaze/controller/error'

module Ramaze

  # The Controller is responsible for combining and rendering actions.

  class Controller
    include Ramaze::Helper
    extend Ramaze::Helper

    helper :redirect, :link, :file, :flash, :cgi

    # Whether or not to map this controller on startup automatically

    trait[:automap] ||= true

    # Place to map the Controller to, this is something like '/' or '/foo'

    trait[:map] ||= nil

    # Modules that are excluded from the Action lookup

    trait :exclude_action_modules => [Kernel, Object, PP::ObjectMixin]

    # Caches patterns for the given path.

    trait :pattern_cache => Hash.new{|h,k| h[k] = Controller.pattern_for(k) }

    class << self
      include Ramaze::Helper
      extend Ramaze::Helper

      # When Controller is subclassed the resulting class is placed in
      # Global.controllers and a new trait :actions_cached is set on it.

      def inherited controller
        controller.trait :actions_cached => {}
        controller.trait :layout => {:all => nil, :deny => Set.new}
        Global.controllers << controller
        if map = controller.mapping
          Inform.dev("mapping #{map} => #{controller}")
          Global.mapping[map] ||= controller
        end
      end

      # called from Ramaze.startup, adds Cache.actions and Cache.patterns, walks
      # all controllers subclassed so far and adds them to the Global.mapping if
      # they are not assigned yet.

      def startup options = {}
        Inform.dev("found Controllers: #{Global.controllers.inspect}")
        tr, pr = Global.template_root, Global.public_root
        Inform.warn("Template root: #{tr} doesn't exist") unless File.directory?(tr)
        Inform.warn("Public root: #{pr} doesn't exist") unless File.directory?(pr)

        if Global.mapping.empty?
          Inform.warn("No Controllers mapped, will serve /public only.")
        else
          Inform.debug("mapped Controllers: #{Global.mapping.inspect}")
        end
      end

      # checks paths for existance and logs a warning if it doesn't exist yet.

      def check_path(path, message)
        Inform.warn(message) unless File.directory?(path)
      end

      # if trait[:automap] is set and controller is not in Global.mapping yet
      # this will build a new default mapping-point, MainController is put
      # at '/' by default.

      def mapping
        global_mapping = Global.mapping.invert[self]
        return global_mapping if global_mapping
        if ancestral_trait[:automap]
          name = self.to_s.gsub('Controller', '').split('::').last
          name == 'Main' ? '/' : "/#{name.snake_case}"
        end
      end

      # Map Controller to the given syms or strings.
      # Replaces old mappings.
      # If you want to _add_ a mapping, just modify Global.mapping.

      def map(*syms)
        Global.mapping.delete_if{|k,v| v == self}

        syms.each do |sym|
          Global.mapping[sym.to_s] = self
        end
      end

      # Returns the Controller at a mapped path.

      def at(mapping)
        Global.mapping[mapping.to_s]
      end

      # Define a layout for all actions on this controller
      #
      # Example:
      #   class Foo < Ramaze::Controller
      #     layout :foo
      #   end
      #
      #  This defines the action :foo to be layout of the controller and will
      #  render the layout after any other action has been rendered, assigns
      #  @content to the result of the action and then goes on rendering
      #  the layout-action where @content may or may not be used, returning
      #  whatever the layout returns.

      def layout(meth_or_hash)
        if meth_or_hash.respond_to?(:to_hash)
          meth_or_hash.each do |layout_name, *actions|
            layout_name = R(self, layout_name) if layout_name.to_s !~ /\A\//
            actions.flatten.each do |action|
              trait[:layout][action.to_s] = layout_name
            end
          end
        else
          layout_name = R(self, meth_or_hash) if meth_or_hash.to_s !~ /\A\//
          trait[:layout][:all] = layout_name || meth_or_hash
        end
      end

      def deny_layout(*actions)
        actions.each do |action|
          trait[:layout][:deny] << action.to_s
        end
      end

      # Define a template_root for Controller, returns the current template_root
      # if no argument is given.
      # Runs every given path through Controller::check_path

      def template_root path = nil
        if path
          message = "#{self}.template_root is #{path} which does not exist"
          check_path(path, message)
          @template_root = path
        else
          @template_root
        end
      end

      # This is used for template rerouting, takes action, optionally a
      # controller and action to route to.
      #
      # Usage:
      #   class MainController
      #     template :index, OtherController, :list
      #     template :foo, :bar
      #
      #     def index
      #       'will use template from OtherController#list'
      #     end
      #
      #     def foo
      #       'will use template from self#bar'
      #     end
      #   end

      def template(this, from, that = nil)
        from, that = self, from unless that
        trait "#{this}_template" => [from, that.to_s]
      end

      def engine(name)
        name = Ramaze::Template.const_get(name)
      rescue NameError => ex
        Inform.warn ex
        Inform.warn "Try to use passed engine directly"
      ensure
        trait :engine => name
      end

      # Return Controller of current Action

      def current
        action = Action.current
        action.instance || action.controller
      end

      # Entering point for Dispatcher, first Controller::resolve(path) and then
      # renders the resulting Action.

      def handle path
        action = resolve(path)
        Thread.current[:controller] = action.controller
        action.render
      end
    end

    private

    # Simplistic render, rerouting to Controller.handle(*args)

    def render *args
      self.class.handle(*args)
    end
  end
end
