#!/usr/bin/env ruby

Encoding.default_external = Encoding::UTF_8

$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), "lib")))

require "chef/resource_inspector"
require "erb"

# given an array ``bold`` the values, comma separate them, and put include 'and' if 3+
# @return String
def bolded_friendly_list(arr)
  arr.map! { |x| "``#{x}``" }
  if arr.size > 2
    arr[-1] = "and #{arr[-1]}"
  end
  arr.join(', ')
end

# given an array of types print out a single comma separated string
# handling a nil value that needs to be printed as "nil" and TrueClass/FalseClass
# which needs to be "true" and "false"
# @return String
def friendly_types_list(arr)
  fixed_arr = Array(arr).map do |x|
    if x.nil?
      "nil"
    else
      case x
      when "TrueClass"
        "true"
      when "FalseClass"
        "false"
      else
        x
      end
    end
  end
  fixed_arr.join(', ')
end

# Makes sure the resource name is bolded within the description
# @return String
def bolded_description(name, description)
  return nil if description.nil? # handle resources missing descriptions
  description.gsub(name, "**#{name}**")
end

template = %{=====================================================
<%= @name %>
=====================================================
`[edit on GitHub] <https://github.com/chef/chef-web-docs/blob/master/chef_master/source/resource_<%= @name %>.rst>`__

<%= bolded_description(@name, @description) %>
<% unless @introduced.nil? %>
**New in Chef Client <%= @introduced %>.**
<% end %>
Syntax
=====================================================
This resource has the following syntax:

.. code-block:: ruby

   <%= @name %> 'name' do
<% @properties.each do |p| %>
<% next if p['name'] == 'name' %>
     <%= p['name'] %>                     <%= friendly_types_list(p['is']) %><% unless p['default'].nil? || p['default'] == "lazy default"  %> # default value: <%= p['default'] %><% end %>
<% end %>
     action                     Symbol # defaults to :<%= @default_action.first %> if not specified
   end

where:

* ``<%= @name %>`` is the resource.
* <%= bolded_friendly_list(@properties[0..-2].collect {|x| x['name']}) %> are the properties available to this resource.

Actions
=====================================================

This resource has the following actions:
<% @actions.each do |a| %>
``:<%= a %>``
   <% if a == @default_action %>Default. <% end %> Description here.
<% end %>
``:nothing``
   .. tag resources_common_actions_nothing

   Define this resource block to do nothing until notified by another resource to take action. When this resource is notified, this resource block is either run immediately or it is queued up to be run at the end of the Chef Client run.

   .. end_tag

Properties
=====================================================

This resource has the following properties:
<% @properties.each do |p| %>
``<%= p['name'] %>``
   **Ruby Type:** <%= friendly_types_list(p['is']) %><% unless p['default'].nil? %> | **Default Value:** ``<%= p['default'] %>``<% end %><% if p['deprecated'] %> | ``DEPRECATED``<% end %><% if p['name_property'] %> | **Default Value:** ``'name'``<% end %>

   <%= p['description'] %>
<% unless p['introduced'].nil? %>   New in Chef Client <%= p['introduced'] %>.<% end %>
<% end %>
}

resources = Chef::JSONCompat.parse(ResourceInspector.inspect)
resources.each do |resource, data|
  next if %w(l_w_r_p_base user_resource_abstract_base_class linux_user pw_user aix_user dscl_user solaris_user windows_user).include?(resource) || resource.nil?
  puts "Writing out #{resource}."
  @name = resource
  @description = data['description']
  @default_action = data['default_action']
  @actions = (data['actions'] - ["nothing"]).sort
  @examples = data['examples']
  @introduced = data['introduced']
  @preview = data['preview']
  @properties = data['properties'].sort_by! { |v| v['name'] }

  t = ERB.new(template)
  File.open("resource_#{@name}.rst", 'w') do |f|
  f.write t.result(binding)
  end
end
