require_dependency Rails.root.join('app', 'controllers', 'admin', 'verifications_controller').to_s

class Admin::VerificationsController

  def request_verification
    failed = false
    users = User.where(id: params[:user_ids])
    users.each do |user|
      user.terms_of_service = '1' # Admin operation
      # NOTE 'mode: :manual' in merged attributes bypass residence web service verification
      residence_params = ActionController::Parameters.new({ residence: user.attributes }).
        require(:residence).
        permit(:document_number, :document_type, :common_name, :first_surname, :date_of_birth, :postal_code, :terms_of_service).
        merge(user: user, official: current_user, mode: :manual, terms_of_service: '1')
      begin
        residence = Verification::Residence.new(residence_params)
        failed = true unless residence.save
      rescue Exception => e
        STDERR.puts ""
        STDERR.puts "****** ERROR querying residence web service for user #{user.id}"
        STDERR.puts e.message
        STDERR.puts e.backtrace[0..9]
        STDERR.puts "****** /ERROR querying residence web service"
        STDERR.puts ""
        redirect_to admin_verifications_path, alert: t('verification.residence.create.flash.error')
        return
      end
      Mailer.email_verification_residence(user.email, failed).deliver_later
    end
    if failed
      redirect_to admin_verifications_path, alert: t('verification.residence.create.flash.failure')
    else
      redirect_to admin_verifications_path, notice: t('verification.residence.create.flash.success')
    end
  end

end
