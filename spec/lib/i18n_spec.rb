#
# Copyright (C) 2011 Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.
#

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper.rb')

describe I18n do
  context "html safety" do
    it "should not return a SafeBuffer if no SafeBuffers are interpolated" do
      translation = I18n.t(:foo, "I want %{number} widgets from %{company}", :number => 2, :company => "Acme Co.")
      # even though Fixnum is html_safe, that shouldn't trigger our html_safe
      # fu (since we don't necessarily want things html-escaped)
      translation.html_safe?.should be_false
      translation.should eql("I want 2 widgets from Acme Co.")
    end

    it "should return a SafeBuffer if a SafeBuffer is interpolated" do
      translation = I18n.t(:foo, "I want %{text_field} widgets", :text_field => "<input>".html_safe)
      translation.html_safe?.should be_true
      translation.should eql("I want <input> widgets")
    end

    it "should html_escape the translation if a SafeBuffer is interpolated" do
      translation = I18n.t(:foo, "If you create an <input> tag, you will see %{text_field}", :text_field => "<input>".html_safe)
      translation.html_safe?.should be_true
      translation.should eql("If you create an &lt;input&gt; tag, you will see <input>")
    end

    it "should html_escape unsafe interpolated variables if a SafeBuffer is interpolated" do
      translation = I18n.t(:foo, "If you create an %{unsafe_tag} tag, you will see %{tag}", :unsafe_tag => "<input>", :tag => "<input>".html_safe)
      translation.html_safe?.should be_true
      translation.should eql("If you create an &lt;input&gt; tag, you will see <input>")
    end
  end
end