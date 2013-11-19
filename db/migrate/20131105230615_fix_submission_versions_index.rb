class FixSubmissionVersionsIndex < ActiveRecord::Migration
  tag :postdeploy
  disable_ddl_transaction!

  def self.up
    if connection.adapter_name == 'PostgreSQL' && connection.select_value("SELECT 1 FROM pg_index WHERE indexrelid='index_submission_versions'::regclass AND NOT indisunique")
      columns = [:context_id, :version_id, :user_id, :assignment_id]
      SubmissionVersion.select(columns).where(context_type: 'Course').group(columns).having("COUNT(*) > 1").find_each do |sv|
        scope = SubmissionVersion.where(Hash[columns.map { |c| [c, sv[c]]}]).where(context_type: 'Course')
        keeper = scope.first
        scope.where("id<>?", keeper).delete_all
      end
      add_index :submission_versions, columns,
                :name => 'index_submission_versions2',
                :where => { :context_type => 'Course' },
                :unique => true
      connection.execute("DROP INDEX IF EXISTS index_submission_versions")
      connection.execute("ALTER INDEX index_submission_versions2 RENAME TO index_submission_versions")
    end
  end
end
