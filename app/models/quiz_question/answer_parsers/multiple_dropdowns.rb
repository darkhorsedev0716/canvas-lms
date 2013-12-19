#
# Copyright (C) 2013 Instructure, Inc.
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

module QuizQuestion::AnswerParsers
  class MultipleDropdowns < AnswerParser
    def parse(question)
      variables = HashWithIndifferentAccess.new

      @answers.map! do |answer_group, answer|
        fields = QuizQuestion::RawFields.new(answer)

        a = {
            id: fields.fetch(:id, nil),
            text: fields.fetch_with_enforced_length(:answer_text),
            comments: fields.fetch_with_enforced_length(:answer_comments),
            weight: fields.fetch(:answer_weight, 0).to_f,
            blank_id: fields.fetch_with_enforced_length(:blank_id)
        }

        answer = QuizQuestion::AnswerGroup::Answer.new(a)
        variables[answer[:blank_id]] ||= false
        variables[answer[:blank_id]] = true if answer.correct?

        answer_group.taken_ids << answer.set_id(answer_group.taken_ids)
        answer
      end
      question.answers = @answers

      variables.each do |variable, found_correct|
        if !found_correct
          question.answers.each_with_index do |answer, idx|
            if answer[:blank_id] == variable && !found_correct
              question.answers[idx][:weight] = 100
              found_correct = true
            end
          end

        end
      end

      question
    end
  end
end
