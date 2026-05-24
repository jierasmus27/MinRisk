# frozen_string_literal: true

require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    User.create!(operator_id: "operator-1", password: "secret-key-12")
    post session_path, params: { operator_id: "operator-1", password: "secret-key-12" }

    @company = Company.create!(name: "Acme", country_iso: "US")
  end

  test "new uses the same project settings layout as show" do
    get new_company_project_path(@company)

    assert_response :success
    assert_select "h1", text: "Project Settings"
    assert_select "h2", text: "Project Information"
    assert_select "h2", text: "Project Logo"
    assert_select "input[type=submit][value='Create project']"
  end

  test "create redirects to project settings, not scope and inputs" do
    post company_projects_path(@company), params: {
      project: {
        name: "North Expansion",
        currency_iso: "USD",
        confidence_levels: [ 50 ]
      }
    }

    project = @company.projects.order(:id).last
    assert_redirected_to company_project_path(@company, project)
    assert_equal "Project created.", flash[:notice]
  end
end
