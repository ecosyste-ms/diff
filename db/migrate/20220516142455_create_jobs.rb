class CreateJobs < ActiveRecord::Migration[7.0]
  def change
    create_table :jobs do |t|
      t.string :sidekiq_id
      t.string :status
      t.string :url_1
      t.string :url_2
      t.string :ip
      t.string :sha256_1
      t.string :sha256_2

      t.timestamps
    end
  end
end

class CreateJobs < ActiveRecord::Migration[7.0]
  def change
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')

    create_table :jobs, id: :uuid, default: 'gen_random_uuid()' do |t|
      t.string :sidekiq_id
      t.string :status
      t.string :url_1
      t.string :url_2
      t.string :ip
      t.string :sha256_1
      t.string :sha256_2
      t.json :results, default: {}

      t.timestamps
    end
  end
end
