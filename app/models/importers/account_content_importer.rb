module Importers
  class AccountContentImporter < Importer

    self.item_class = Account
    Importers.register_content_importer(self)

    def self.import_content(account, data, params, migration)

      migration.migration_settings[:import_quiz_questions_without_quiz] = true
      Importers::AssessmentQuestionImporter.process_migration(data, migration)
      Importers::LearningOutcomeImporter.process_migration(data, migration)

      migration.progress = 100
      migration.workflow_state = :imported
      migration.save
    end
  end
end