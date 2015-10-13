require_dependency 'single_sign_on'

class DiscourseSingleSignOn < SingleSignOn

  def self.sso_url
    SiteSetting.sso_url
  end

  def self.sso_secret
    SiteSetting.sso_secret
  end

  def self.generate_url(return_path="/")
    sso = new
    sso.nonce = SecureRandom.hex
    sso.register_nonce(return_path)
    sso.return_sso_url = Discourse.base_url + "/session/sso_login"
    sso.to_url
  end

  def register_nonce(return_path)
    if nonce
      $redis.setex(nonce_key, NONCE_EXPIRY_TIME, return_path)
    end
  end

  def nonce_valid?
    nonce && $redis.get(nonce_key).present?
  end

  def return_path
    $redis.get(nonce_key) || "/"
  end

  def expire_nonce!
    if nonce
      $redis.del nonce_key
    end
  end

  def nonce_key
    "SSO_NONCE_#{nonce}"
  end

  def lookup_or_create_user
    sso_record = SingleSignOnRecord.find_by(external_id: external_id)

    if sso_record && user = sso_record.user
      sso_record.last_payload = unsigned_payload
    else
      user = match_email_or_create_user
      sso_record = user.single_sign_on_record
    end

    # if the user isn't new or it's attached to the SSO record we might be overriding username or email
    unless user.new_record?
      change_external_attributes_and_override(sso_record, user)
    end

    if sso_record && (user = sso_record.user) && !user.active
      user.active = true
      user.save!
      user.enqueue_welcome_message('welcome_user')
    end

    custom_fields.each do |k,v|
      user.custom_fields[k] = v
    end

    user.admin = admin unless admin.nil?
    user.moderator = moderator unless moderator.nil?

    # optionally save the user and sso_record if they have changed
    user.save!
    sso_record.save!

    sso_record && sso_record.user
  end

  private

  def match_email_or_create_user
    user = User.find_by_email(email)

    try_name = name.blank? ? nil : name
    try_username = username.blank? ? nil : username

    user_params = {
        email: email,
        name:  User.suggest_name(try_name || try_username || email),
        username: UserNameSuggester.suggest(try_username || try_name || email),
    }

    if user || user = User.create!(user_params)
      if sso_record = user.single_sign_on_record
        sso_record.last_payload = unsigned_payload
        sso_record.external_id = external_id
      else
        user.create_single_sign_on_record(last_payload: unsigned_payload,
                                          external_id: external_id,
                                          external_username: username,
                                          external_email: email,
                                          external_name: name)
      end
    end

    user
  end

  def change_external_attributes_and_override(sso_record, user)
    if SiteSetting.sso_overrides_email && email != sso_record.external_email
      # set the user's email to whatever came in the payload
      user.email = email
    end

    if SiteSetting.sso_overrides_username && username != sso_record.external_username && user.username != username
      # we have an external username change, and the user's current username doesn't match
      # run it through the UserNameSuggester to override it
      user.username = UserNameSuggester.suggest(username || name || email)
    end

    if SiteSetting.sso_overrides_name && name != sso_record.external_name && user.name != name
      # we have an external name change, and the user's current name doesn't match
      # run it through the name suggester to override it
      user.name = User.suggest_name(name || username || email)
    end

    if SiteSetting.sso_overrides_avatar && (
      avatar_force_update == "true" ||
      avatar_force_update.to_i != 0 ||
      sso_record.external_avatar_url != avatar_url)
      begin
        tempfile = FileHelper.download(avatar_url, 1.megabyte, "sso-avatar", true)

        ext = FastImage.type(tempfile).to_s
        tempfile.rewind

        upload = Upload.create_for(user.id, tempfile, "external-avatar." + ext, File.size(tempfile.path), { origin: avatar_url })
        user.uploaded_avatar_id = upload.id

        unless user.user_avatar
          user.build_user_avatar
        end

        if !user.user_avatar.contains_upload?(upload.id)
          user.user_avatar.custom_upload_id = upload.id
        end
      rescue SocketError
        # skip saving, we are not connected to the net
        Rails.logger.warn "Failed to download external avatar: #{avatar_url}, socket error - user id #{ user.id }"
      ensure
        tempfile.close! if tempfile && tempfile.respond_to?(:close!)
      end
    end

    # change external attributes for sso record
    sso_record.external_username = username
    sso_record.external_email = email
    sso_record.external_name = name
    sso_record.external_avatar_url = avatar_url
  end
end