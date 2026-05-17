module ApplicationHelper
  def nav_link_class(active)
    base = "flex items-center gap-4 px-4 py-2 rounded-full transition-colors font-body-md text-body-md "
    if active
      "#{base} bg-primary-container text-on-primary-container font-bold"
    else
      "#{base} text-on-surface-variant hover:bg-surface-container-highest"
    end
  end

  def mobile_nav_class(active)
    base = "flex flex-col items-center justify-center px-4 py-1 rounded min-w-0 flex-1 "
    if active
      "#{base} text-secondary font-bold scale-110"
    else
      "#{base} text-on-surface-variant hover:bg-surface-container-low"
    end
  end

  def dashboard_nav?
    controller_name == "companies" && %w[index show new edit].include?(action_name)
  end

  def scope_nav?
    controller_name == "project_uploads" || (controller_name == "projects" && action_name == "new")
  end

  def scope_inputs_nav_url
    proj = Project.includes(:company).order(:id).first
    proj ? company_project_upload_path(proj.company, proj) : companies_path
  end

  def preview_money(cents, currency_iso)
    return "—" if cents.nil?

    Money.new(cents, currency_iso).format
  end
end
