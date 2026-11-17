module MaintenanceOrderSignaturesHelper
  def maintenance_order_finish_signatures(form_builder, finish_form)
    return unless finish_form.signatures_required?

    render 'maintenance_orders/finish_signatures', f: form_builder, finish_form:
  end

  def maintenance_order_finish_supervisor_options(finish_form)
    finish_form.supervisors.map { |supervisor| [supervisor.name, supervisor.id] }
  end

  def maintenance_order_mechanic_signature(finish_form, mechanic)
    finish_form.mechanic_signatures.to_h.stringify_keys[mechanic.id.to_s]
  end

  def maintenance_order_mechanic_signature_label(mechanic)
    t('maintenance_orders.finish_modal.signature_label', name: mechanic.name,
                                                         role: MaintenanceOrderSignature.human_enum_name(:signer_role_type, :mechanic))
  end

  def maintenance_order_signatures_card(signatures)
    render('maintenance_orders/signatures', signatures:) if signatures.any?
  end

  def maintenance_order_signature_image(signature)
    image_tag("data:image/svg+xml;base64,#{Base64.strict_encode64(signature.to_svg)}",
              alt: t('maintenance_orders.show.signature_alt', name: signature.signer_name), class: 'signature-image')
  end

  def maintenance_order_signature_signed_at(signature)
    t('maintenance_orders.show.signed_at', time: l(signature.signed_at, format: :date_time))
  end

  def maintenance_order_signature_digest(signature)
    t('maintenance_orders.show.content_digest', digest: signature.content_digest)
  end
end
