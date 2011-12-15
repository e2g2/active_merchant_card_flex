require 'test_helper'

class RemoteCardFlexTest < Test::Unit::TestCase

  def setup
    @gateway        = CardFlexGateway.new(fixtures(:card_flex))
    @amount         = 100
    @credit_card    = credit_card('5454545454545454')
    @declined_card  = credit_card('4111111111111112')
    @options        = {
      :order_id         => generate_unique_id,
      :billing_address  => address,
      :description      => 'Test purchase'
    }
  end

  def test_sucessful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert response.test?
    assert_equal 'Accepted', response.message
    assert response.authorization
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Invalid account number', response.message
  end

  def test_successful_credit
    assert response = @gateway.credit(@amount, @credit_card, @options)
    assert_success response
    assert response.test?
    assert_equal 'Accepted', response.message
    assert response.authorization
  end

  def test_authorize_and_capture
    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Accepted', auth.message
    assert auth.authorization

    assert capture = @gateway.capture(amount, auth.authorization)
    assert_success capture
    assert_equal 'Accepted', capture.message
  end

  def test_failed_capture
    authorization = "12345678910"
    assert response = @gateway.capture(@amount, '1234567890')
    assert_failure response
    assert_equal 'ProcessPostTrans... could not load order (123456,)', response.message

    assert response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'Missing account number', response.message
  end

  def test_authorize_and_void
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Accepted', auth.message
    assert auth.authorization

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'Accepted', void.message
  end

  def test_unsuccessful_void
    assert void = @gateway.void('')
    assert_failure void
    assert_equal 'Invalid acct type', void.message
  end

  def test_store_purchase_unstore
    assert store = @gateway.store(@credit_card)
    assert_success store
    assert_equal 'Accepted', store.message

    # wait a few seconds before charging a profile
    sleep 15
    assert purchase = @gateway.purchase(@amount, store.authorization, @options)
    assert_success purchase
    assert_equal 'Accepted', purchase.message

    assert unstore = @gateway.unstore(store.authorization)
    assert_success unstore
    assert_equal 'Accepted', unstore.message
    assert purchase_after_unstore = @gateway.purchase(@amount, store.authorization, @options)
    assert_failure purchase_after_unstore
    assert_equal 'Profile Not Found', purchase_after_unstore.message
  end

  def test_unsuccessful_unstore
    assert unstore = @gateway.unstore('123456789')
    assert_failure unstore
  end
end
