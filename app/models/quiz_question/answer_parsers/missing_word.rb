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
#
module QuizQuestion::AnswerParsers
  class MissingWord < AnswerParser
    def parse(question)
      @answers.map! do |answer_group, answer|
        fields = QuizQuestion::RawFields.new(answer)
        a = {
          text: fields.fetch_with_enforced_length(:answer_text),
          comments: fields.fetch_with_enforced_length(:answer_comments),
          weight: fields.fetch(:answer_weight).to_f
        }

        id = fields.fetch(:id, nil)
        id = id.to_i if id
        a[:id] = id

        answer = QuizQuestion::AnswerGroup::Answer.new(a)
        answer_group.taken_ids << answer.set_id(answer_group.taken_ids)
        answer
      end

      @answers.set_correct_if_none
      fields = QuizQuestion::RawFields.new({text_after_answers: question[:text_after_answers]})
      question[:text_after_answers] = fields.sanitize(fields.fetch_with_enforced_length(:text_after_answers, max_size: 16.kilobyte))

      question.answers = @answers
      question
    end
  end
end

