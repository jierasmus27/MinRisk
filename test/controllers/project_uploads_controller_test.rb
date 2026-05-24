# frozen_string_literal: true

require "test_helper"

class ProjectUploadsControllerTest < ActionDispatch::IntegrationTest
  setup do
    User.create!(operator_id: "operator-1", password: "secret-key-12")
    post session_path, params: { operator_id: "operator-1", password: "secret-key-12" }

    @company = Company.create!(name: "Acme", country_iso: "US")
    @project_a = @company.projects.create!(name: "Alpha", currency_iso: "USD", confidence_levels: [ 50 ])
    @project_b = @company.projects.create!(name: "Beta", currency_iso: "USD", confidence_levels: [ 50 ])
  end

  test "show lists all company projects in the selector" do
    get company_project_upload_path(@company, @project_a)

    assert_response :success
    assert_select "#scope-project-select option[selected]", text: "Alpha"
    assert_select "#scope-project-select option", text: "Beta"
    assert_select "#scope-project-select option[value=?]",
      company_project_upload_path(@company, @project_b)
  end
end
