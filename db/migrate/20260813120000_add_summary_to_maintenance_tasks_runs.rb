# frozen_string_literal: true

class AddSummaryToMaintenanceTasksRuns < ActiveRecord::Migration[5.2]
  def change
    add_column(:maintenance_tasks_runs, :summary, :text)
  end
end
