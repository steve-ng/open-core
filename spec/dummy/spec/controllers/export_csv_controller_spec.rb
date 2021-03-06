require "spec_helper"

describe ExportCsvController do
  let(:export_filename) { "user-archive-999.csv" }


  context "while logged in as normal user" do
    before { @user = log_in(:user) }

    describe ".export_entity" do
      it "enqueues export job" do
        Jobs.expects(:enqueue).with(:export_csv_file, has_entries(entity: "user_archive", user_id: @user.id))
        xhr :post, :export_entity, entity: "user_archive", entity_type: "user"
        expect(response).to be_success
      end

      it "should not enqueue export job if rate limit is reached" do
        Jobs::ExportCsvFile.any_instance.expects(:execute).never
        UserExport.create(export_type: "user", user_id: @user.id)
        xhr :post, :export_entity, entity: "user_archive", entity_type: "user"
        expect(response).not_to be_success
      end

      it "returns 404 when normal user tries to export admin entity" do
        xhr :post, :export_entity, entity: "staff_action", entity_type: "admin"
        expect(response).not_to be_success
      end
    end

    describe ".download" do
      it "uses send_file to transmit the export file" do
        file = UserExport.create(export_type: "user", user_id: @user.id)
        file_name = "user-archive-#{file.id}.csv"
        controller.stubs(:render)
        export = UserExport.new()
        UserExport.expects(:get_download_path).with(file_name).returns(export)
        subject.expects(:send_file).with(export)
        get :show, id: file_name
        expect(response).to be_success
      end

      it "returns 404 when the user tries to export another user's csv file" do
        get :show, id: export_filename
        expect(response).to be_not_found
      end

      it "returns 404 when the export file does not exist" do
        UserExport.expects(:get_download_path).returns(nil)
        get :show, id: export_filename
        expect(response).to be_not_found
      end
    end
  end


  context "while logged in as an admin" do
    before { @admin = log_in(:admin) }

    describe ".export_entity" do
      it "enqueues export job" do
        Jobs.expects(:enqueue).with(:export_csv_file, has_entries(entity: "staff_action", user_id: @admin.id))
        xhr :post, :export_entity, entity: "staff_action", entity_type: "admin"
        expect(response).to be_success
      end

      it "should not rate limit export for staff" do
        Jobs.expects(:enqueue).with(:export_csv_file, has_entries(entity: "staff_action", user_id: @admin.id))
        UserExport.create(export_type: "admin", user_id: @admin.id)
        xhr :post, :export_entity, entity: "staff_action", entity_type: "admin"
        expect(response).to be_success
      end
    end

    describe ".download" do
      it "uses send_file to transmit the export file" do
        file = UserExport.create(export_type: "admin", user_id: @admin.id)
        file_name = "screened-email-#{file.id}.csv"
        controller.stubs(:render)
        export = UserExport.new()
        UserExport.expects(:get_download_path).with(file_name).returns(export)
        subject.expects(:send_file).with(export)
        get :show, id: file_name
        expect(response).to be_success
      end

      it "returns 404 when the export file does not exist" do
        UserExport.expects(:get_download_path).returns(nil)
        get :show, id: export_filename
        expect(response).to be_not_found
      end
    end
  end

end
