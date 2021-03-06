# License: AGPL-3.0-or-later WITH Web-Template-Output-Additional-Permission-3.0-or-later
require 'psql'
require 'qexpr'
require 'i18n'

module InsertSupporter

  def self.create_or_update(np_id, data, update=false)
    ParamValidation.new(data.merge(np_id: np_id), {
      np_id: {required: true, is_integer: true}
    })
    address_keys = ['name', 'address', 'city', 'country', 'state_code']
    custom_fields = data['customFields']
    data = HashWithIndifferentAccess.new(Format::RemoveDiacritics.from_hash(data, address_keys))
      .except(:customFields)

    supporter = Qx.select("*").from(:supporters)
      .where("name = $n AND email = $e", n: data[:name], e: data[:email])
      .and_where("nonprofit_id=$id", id: np_id)
      .and_where("coalesce(deleted, FALSE)=FALSE")
      .execute.last
		if supporter and update
      supporter = Qx.update(:supporters)
        .set(defaults(data))
        .where("id=$id", id: supporter['id'])
        .returning('*')
        .timestamps
        .execute.last
		else
      supporter = Qx.insert_into(:supporters)
        .values(defaults(data).merge(nonprofit_id: np_id))
        .returning('*')
        .timestamps
        .execute.last
		end

    if custom_fields
      InsertCustomFieldJoins.find_or_create(np_id, [supporter['id']],  custom_fields)
    end

    #GeocodeModel.delay.supporter(supporter['id'])
    InsertFullContactInfos.enqueue([supporter['id']])

    return supporter
  end


	def self.defaults(h)
    h = h.except('profile_id') unless h['profile_id'].present?
		if h['first_name'].present? || h['last_name'].present?
			h['name'] = h['first_name'] || h['last_name']
			if h['first_name'] && h['last_name']
				h['name'] = "#{h['first_name'].strip} #{h['last_name'].strip}"
			end
		end

    h['email_unsubscribe_uuid'] = SecureRandom.uuid

    if h['address'].present? && h['address_line2'].present?
      h['address'] += ' ' + h['address_line2']
    end

    h = h.except('address_line2')

		return h
	end

  # pass in a hash of supporter info, as well as
  # any property with tag_x will create a tag with name 'name'
  # any property with field_x will create a field with name 'x' and value set
  # eg:
  # {
  #   'name' => 'Bob Ross',
  #   'email' => 'bob@happytrees.org',
  #   'tag_xy' => true,
  #   'field_xy' => 420
  # }
  # The above will create a supporter with name/email, one tag with name 'xy',
  # and one field with name 'xy' and value 420
  def self.with_tags_and_fields(np_id, data)
    tags = data.select{|key, val| key.match(/^tag_/)}.map{|key, val| key.gsub('tag_', '')}
    fields = data.select{|key, val| key.match(/^field_/)}.map{|key, val| [key.gsub('field_', ''), val]}
    supp_cols = data.select{|key, val| !key.match(/^field_/) && !key.match(/^tag_/)}
    supporter = create_or_update(np_id, supp_cols)

    InsertTagJoins.delay.find_or_create(np_id, [supporter['id']], tags) if tags.any?
    InsertCustomFieldJoins.delay.find_or_create(np_id, [supporter['id']], fields) if fields.any?

    return supporter
  end

end
