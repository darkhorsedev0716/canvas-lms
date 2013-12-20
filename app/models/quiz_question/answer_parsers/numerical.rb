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
  class Numerical < AnswerParser
    def parse(question)
      @answers.map! do |answer_group, answer|
        fields = QuizQuestion::RawFields.new(answer)

        a = {
          id: fields.fetch(:id, nil),
          text: fields.fetch_with_enforced_length(:answer_text),
          comments: fields.fetch_with_enforced_length(:answer_comments),
          weight: 100
        }

        a[:numerical_answer_type] = fields.fetch(:numerical_answer_type)

        if a[:numerical_answer_type] == "exact_answer"
          a[:exact] = fields.fetch(:answer_exact).to_f
          a[:margin] = fields.fetch(:answer_error_margin).to_f
        else
          a[:numerical_answer_type] = "range_answer"
          a[:start] = fields.fetch(:answer_range_start).to_f
          a[:end] = fields.fetch(:answer_range_end).to_f
        end

        answer = QuizQuestion::AnswerGroup::Answer.new(a)
        answer_group.taken_ids << answer.set_id(answer_group.taken_ids)
        answer
      end

      question.answers = @answers
      question
    end
  end
end

