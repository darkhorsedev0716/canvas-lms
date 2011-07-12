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

class UserListsController < ApplicationController
  skip_before_filter :verify_authenticity_token
  
  # POST /user_lists.js
  def create
    @user_list = UserList.new(params[:user_list])

    respond_to do |format|
      if @user_list
        format.json  { render :json => @user_list }
      else
        format.json  { render :json => @user_list.errors, :status => :unprocessable_entity }
      end
    end
  end
end
