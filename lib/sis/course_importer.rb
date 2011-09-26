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

require "skip_callback"

module SIS
  class CourseImporter

    def initialize(batch_id, root_account, logger)
      @batch_id = batch_id
      @root_account = root_account
      @logger = logger
    end

    def process(messages)
      start = Time.now
      courses_to_update_sis_batch_id = []
      course_ids_to_update_associations = [].to_set

      importer = Work.new(@batch_id, @root_account, @logger, courses_to_update_sis_batch_id, course_ids_to_update_associations, messages)
      Course.skip_callback(:update_enrollments_later) do
        Course.skip_updating_account_associations do
          yield importer
        end
      end

      Course.update_account_associations(course_ids_to_update_associations.to_a) unless course_ids_to_update_associations.empty?
      Course.update_all({:sis_batch_id => @batch_id}, {:id => courses_to_update_sis_batch_id}) if @batch_id && !courses_to_update_sis_batch_id.empty?
      @logger.debug("Courses took #{Time.now - start} seconds")
      return importer.success_count
    end

  private

    class Work
      attr_accessor :success_count

      def initialize(batch_id, root_account, logger, a1, a2, m)
        @batch_id = batch_id
        @root_account = root_account
        @courses_to_update_sis_batch_id = a1
        @course_ids_to_update_associations = a2
        @messages = m
        @logger = logger
        @success_count = 0
      end

      def add_course(course_id, term_id, account_id, fallback_account_id, status, start_date, end_date, abstract_course_id, short_name, long_name)

        @logger.debug("Processing Course #{[course_id, term_id, account_id, fallback_account_id, status, start_date, end_date, abstract_course_id, short_name, long_name].inspect}")

        raise ImportError, "No course_id given for a course" if course_id.blank?
        raise ImportError, "No short_name given for course #{course_id}" if short_name.blank? && abstract_course_id.blank?
        raise ImportError, "No long_name given for course #{course_id}" if long_name.blank? && abstract_course_id.blank?
        raise ImportError, "Improper status \"#{status}\" for course #{course_id}" unless status =~ /\A(active|deleted|completed)/i


        term = @root_account.enrollment_terms.find_by_sis_source_id(term_id)
        course = Course.find_by_root_account_id_and_sis_source_id(@root_account.id, course_id)
        course ||= Course.new
        course.enrollment_term = term if term
        course.root_account = @root_account

        account = nil
        account = Account.find_by_root_account_id_and_sis_source_id(@root_account.id, account_id) if account_id.present?
        account ||= Account.find_by_root_account_id_and_sis_source_id(@root_account.id, fallback_account_id) if fallback_account_id.present?
        course.account = account if account
        course.account ||= @root_account

        update_account_associations = course.account_id_changed? || course.root_account_id_changed?

        course.sis_source_id = course_id
        if status =~ /active/i
          if course.workflow_state == 'completed'
            course.workflow_state = 'available'
          elsif course.workflow_state != 'available'
            course.workflow_state = 'claimed'
          end
        elsif status =~ /deleted/i
          course.workflow_state = 'deleted'
        elsif status =~ /completed/i
          course.workflow_state = 'completed'
        end

        course.start_at = start_date
        course.conclude_at = end_date
        course.restrict_enrollments_to_course_dates = (course.start_at.present? || course.conclude_at.present?)

        abstract_course = nil
        if abstract_course_id.present?
          abstract_course = AbstractCourse.find_by_root_account_id_and_sis_source_id(@root_account.id, abstract_course_id)
          @messages << "unknown abstract course id #{abstract_course_id}, ignoring abstract course reference" unless abstract_course
        end

        if abstract_course
          if term_id.blank? && course.enrollment_term_id != abstract_course.enrollment_term
            course.send(:association_instance_set, :enrollment_term, nil)
            course.enrollment_term_id = abstract_course.enrollment_term_id
          end
          if account_id.blank? && course.account_id != abstract_course.account_id
            course.send(:association_instance_set, :account, nil)
            course.account_id = abstract_course.account_id
          end
        end
        course.abstract_course = abstract_course

        # only update the name/short_name on new records, and ones that haven't been changed
        # since the last sis import
        if course.short_name.blank? || course.sis_course_code == course.short_name
          if short_name.present?
            course.short_name = course.sis_course_code = short_name
          elsif abstract_course && course.short_name.blank?
            course.short_name = course.sis_course_code = abstract_course.short_name
          end
        end
        if course.name.blank? || course.sis_name == course.name
          if long_name.present?
            course.name = course.sis_name = long_name
          elsif abstract_course && course.name.blank?
            course.name = course.sis_name = abstract_course.name
          end
        end

        update_enrollments = !course.new_record? && !(course.changes.keys & ['workflow_state', 'name', 'course_code']).empty?
        if course.changed?
          course.templated_courses.each do |templated_course|
            templated_course.root_account = @root_account
            templated_course.account = course.account
            if templated_course.sis_name && templated_course.sis_name == templated_course.name && course.sis_name && course.sis_name == course.name
              templated_course.name = course.name
              templated_course.sis_name = course.sis_name
            end
            if templated_course.sis_course_code && templated_course.sis_course_code == templated_course.short_name && course.sis_course_code && course.sis_course_code == course.short_name
              templated_course.sis_course_code = course.sis_course_code
              templated_course.short_name = course.short_name
            end
            templated_course.enrollment_term = course.enrollment_term
            templated_course.sis_batch_id = @batch_id if @batch_id
            @course_ids_to_update_associations.add(templated_course.id) if templated_course.account_id_changed? || templated_course.root_account_id_changed?
            templated_course.save_without_broadcasting!
          end
          course.sis_batch_id = @batch_id if @batch_id
          course.save_without_broadcasting!
          @course_ids_to_update_associations.add(course.id) if update_account_associations
        elsif @batch_id
          @courses_to_update_sis_batch_id << course.id
        end

        course.update_enrolled_users if update_enrollments
        @success_count += 1
      end
    end
  end
end
