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

  def projects_nav?
    controller_name == "projects" && %w[show edit update].include?(action_name)
  end

  def scope_nav?
    controller_name == "project_uploads" || (controller_name == "projects" && action_name == "new")
  end

  def projects_nav_url
    proj = Project.includes(:company).order(:id).first
    proj ? company_project_path(proj.company, proj) : companies_path
  end

  def scope_inputs_nav_url
    proj = Project.includes(:company).order(:id).first
    proj ? company_project_upload_path(proj.company, proj) : companies_path
  end

  def preview_money(cents, currency_iso)
    return "—" if cents.nil?

    Money.new(cents, currency_iso).format
  end

  def page_title_class
    "font-headline-lg text-headline-lg text-on-surface"
  end

  def page_subtitle_class
    "font-body-md text-body-md text-on-surface-variant mt-2"
  end

  def card_class
    "bg-surface-container-lowest border border-outline-variant rounded-xl p-6 shadow-sm"
  end

  def card_title_class
    "font-headline-md text-headline-md text-primary"
  end

  def card_title_bar_class
    "mb-4 border-b border-outline-variant pb-2"
  end

  def field_label_class
    "font-label-caps text-label-caps text-on-surface-variant uppercase block mb-1"
  end

  def field_input_class
    "w-full bg-surface border border-outline-variant rounded p-2 font-body-md text-body-md text-on-surface " \
      "focus:border-primary focus:ring-1 focus:ring-primary transition-colors"
  end

  def primary_button_class
    "w-full bg-primary-container text-on-primary-container py-2 rounded font-label-caps text-label-caps " \
      "hover:opacity-90 transition-opacity uppercase tracking-wide cursor-pointer"
  end

  def section_label_class
    "font-label-caps text-label-caps text-on-surface-variant uppercase"
  end

  def body_text_class
    "font-body-md text-body-md text-on-surface-variant"
  end

  def outline_button_class
    "inline-flex items-center justify-center gap-1 px-4 py-2 border border-outline-variant rounded-lg " \
      "font-label-caps text-label-caps text-primary hover:bg-surface-container-low transition-colors uppercase tracking-wide"
  end

  def danger_button_class
    "inline-flex items-center justify-center gap-1 px-4 py-2 border border-error/30 rounded-lg " \
      "font-label-caps text-label-caps text-error hover:bg-error-container/20 transition-colors uppercase tracking-wide"
  end
end
