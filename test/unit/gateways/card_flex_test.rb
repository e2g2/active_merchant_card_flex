require 'test_helper'

class CardFlexTest < Test::Unit::TestCase
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

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert_equal '1921788665454', response.authorization
    assert response.test?
  end

  def test_unsuccessful_purchase
    @gateway.expects(:ssl_post).returns(failed_purchase_response)
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_authorization
    @gateway.expects(:ssl_post).returns(successful_authorization_response)
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert response.success?
    assert_equal '1921799375454', response.authorization
    assert response.test?
  end

  def test_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)
    assert response = @gateway.capture(@amount, '1921799375454', @options)
    assert response.success?
    assert_equal '1921799405454', response.authorization
    assert response.test?
  end

  def test_credit
    @gateway.expects(:ssl_post).returns(successful_credit_response)
    assert_success @gateway.credit(@amount, @credit_card, @options)
  end

  def test_void
    @gateway.expects(:ssl_post).returns(successful_void_response)
    assert response = @gateway.void('1921799375454')
    assert response.success?
    assert_equal '1921796055454', response.authorization
    assert response.test?
  end

  def test_store
    @gateway.expects(:ssl_post).returns(successful_store_response)
    assert response = @gateway.store(@credit_card)
    assert response.success?
    assert_equal '65567155454', response.authorization
    assert response.test?
  end

  def test_unstore
    @gateway.expects(:ssl_post).returns(successful_unstore_response)
    assert response = @gateway.unstore('65567155454')
    assert response.success?
    assert_equal nil, response.authorization
    assert response.test?
  end

  def test_successful_avs_check
    @gateway.expects(:ssl_post).returns(successful_purchase_response.gsub('192178866:N::U', '192178866:Y::U'))
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal response.avs_result['code'], "Y"
    assert_equal response.avs_result['message'], "Street address and 5-digit postal code match."
    assert_equal response.avs_result['street_match'], "Y"
    assert_equal response.avs_result['postal_match'], "Y"
  end

  def test_unsuccessful_avs_check_with_bad_street_address
    @gateway.expects(:ssl_post).returns(successful_purchase_response.gsub('192178866:N::U', '192178866:Z::U'))
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal response.avs_result['code'], "Z"
    assert_equal response.avs_result['message'], "Street address does not match, but 5-digit postal code matches."
    assert_equal response.avs_result['street_match'], "N"
    assert_equal response.avs_result['postal_match'], "Y"
  end

  def test_unsuccessful_avs_check_with_bad_zip
    @gateway.expects(:ssl_post).returns(successful_purchase_response.gsub('192178866:N::U', '192178866:A::U'))
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal response.avs_result['code'], "A"
    assert_equal response.avs_result['message'], "Street address matches, but 5-digit and 9-digit postal code do not match."
    assert_equal response.avs_result['street_match'], "Y"
    assert_equal response.avs_result['postal_match'], "N"
  end

  def test_successful_cvv_check
    @gateway.expects(:ssl_post).returns(successful_purchase_response.gsub('192178866:N::U', '192178866:N::M'))
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal response.cvv_result['code'], "M"
    assert_equal response.cvv_result['message'], "Match"
  end

  def test_unsuccessful_cvv_check
    @gateway.expects(:ssl_post).returns(successful_purchase_response.gsub('192178866:N::U', '192178866:N::N'))
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal response.cvv_result['code'], "N"
    assert_equal response.cvv_result['message'], "No Match"
  end

  def test_supported_countries
    assert_equal ['US'], CardFlexGateway.supported_countries
  end

  def test_supported_card_types
    assert_equal [:visa, :master, :american_express, :discover], CardFlexGateway.supported_cardtypes
  end

  private
    def successful_purchase_response
      <<-eos.gsub(/^ {6}/, '').gsub("\n", "\r\n")
      <html><body><plaintext>
      Accepted=AVSAUTH:TEST:::192178866:N::U
      historyid=192178866
      orderid=141639490
      Accepted=AVSAUTH:TEST:::192178866:N::U
      ACCOUNTNUMBER=************5454
      authcode=TEST
      AuthNo=AVSAUTH:TEST:::192178866:N::U
      ENTRYMETHOD=KEYED
      historyid=192178866
      MERCHANTORDERNUMBER=d86139833ae6f675c21931d1ca68a674
      orderid=141639490
      PAYTYPE=MasterCard
      recurid=0
      refcode=192178866-TEST
      result=1
      Status=Accepted
      transid=0
      eos
    end

    def successful_authorization_response
      <<-eos.gsub(/^ {6}/, '').gsub("\n", "\r\n")
      <html><body><plaintext>
      Accepted=AVSAUTH:TEST:::192179937:N::U
      historyid=192179937
      orderid=141640360
      Accepted=AVSAUTH:TEST:::192179937:N::U
      ACCOUNTNUMBER=************5454
      authcode=TEST
      AuthNo=AVSAUTH:TEST:::192179937:N::U
      ENTRYMETHOD=KEYED
      historyid=192179937
      MERCHANTORDERNUMBER=dd9d22bc626a793e039975bdc3f70eda
      orderid=141640360
      PAYTYPE=MasterCard
      recurid=0
      refcode=192179937-TEST
      result=1
      Status=Accepted
      transid=0
      eos
    end

    def successful_credit_response
      <<-eos.gsub(/^ {6}/, '').gsub("\n", "\r\n")
      <html><body><plaintext>
      Accepted=CREDIT:TEST:::192180043:::
      historyid=192180043
      orderid=141640416
      Accepted=CREDIT:TEST:::192180043:::
      ACCOUNTNUMBER=************5454
      authcode=TEST
      AuthNo=CREDIT:TEST:::192180043:::
      ENTRYMETHOD=KEYED
      historyid=192180043
      MERCHANTORDERNUMBER=1fe19bf710c5800dcef50fa9572b8962
      orderid=141640416
      PAYTYPE=MasterCard
      recurid=0
      refcode=192180043-TEST
      result=1
      Status=Accepted
      transid=0
      eos
    end

    def successful_void_response
      <<-eos.gsub(/^ {6}/, '').gsub("\n", "\r\n")
      <html><body><plaintext>
      Accepted=VOID:TEST:::192179605:::
      historyid=192179605
      orderid=141640067
      Accepted=VOID:TEST:::192179605:::
      ACCOUNTNUMBER=************5454
      authcode=TEST
      AuthNo=VOID:TEST:::192179605:::
      ENTRYMETHOD=KEYED
      historyid=192179605
      MERCHANTORDERNUMBER=42ecde63168c401ccb02a40171aa0042
      orderid=141640067
      PAYTYPE=MasterCard
      recurid=0
      refcode=192179605-TEST
      result=1
      Status=Accepted
      transid=0
      eos
    end

    def successful_capture_response
      <<-eos.gsub(/^ {6}/, '').gsub("\n", "\r\n")
      <html><body><plaintext>
      Accepted=AVSPOST:TEST:::192179940:::
      historyid=192179940
      orderid=141640360
      Accepted=AVSPOST:TEST:::192179940:::
      ACCOUNTNUMBER=************5454
      authcode=TEST
      AuthNo=AVSPOST:TEST:::192179940:::
      ENTRYMETHOD=KEYED
      historyid=192179940
      MERCHANTORDERNUMBER=dd9d22bc626a793e039975bdc3f70eda
      orderid=141640360
      PAYTYPE=MasterCard
      recurid=0
      refcode=192179940-TEST
      result=1
      Status=Accepted
      transid=192179937
      eos
    end

    def successful_store_response
      <<-eos.gsub(/^ {6}/, '').gsub("\n", "\r\n")
      <html><body><plaintext>
      Accepted=AVSAUTH:TEST:::192179530:N::U:DUPLICATE
      historyid=192179530
      orderid=141640000
      Accepted=AVSAUTH:TEST:::192179530:N::U:DUPLICATE
      ACCOUNTNUMBER=************5454
      authcode=TEST
      AuthNo=AVSAUTH:TEST:::192179530:N::U:DUPLICATE
      DUPLICATE=1
      ENTRYMETHOD=KEYED
      historyid=192179530
      orderid=141640000
      PAYTYPE=MasterCard
      recurid=0
      refcode=192179530-TEST
      result=1
      Status=Accepted
      transid=0
      USERPROFILEID=6556715
      eos
    end

    def successful_unstore_response
      <<-eos.gsub(/^ {6}/, '').gsub("\n", "\r\n")
      <html><body><plaintext>
      Accepted=PROFILEDELETE:Success:::0:::
      historyid=0
      orderid=
      Accepted=PROFILEDELETE:Success:::0:::
      authcode=Success
      AuthNo=PROFILEDELETE:Success:::0:::
      historyid=0
      refcode=
      result=1
      Status=Accepted
      transid=0
      USERPROFILEID=6556715
      eos
    end

    def failed_purchase_response
      <<-eos.gsub(/^ {6}/, '').gsub("\n", "\r\n")
      <html><body><plaintext>
      Declined=DECLINED:1101610001:Invalid account number:
      historyid=192179887
      orderid=141640315
      ACCOUNTNUMBER=************1112
      Declined=DECLINED:1101610001:Invalid account number:
      ENTRYMETHOD=KEYED
      historyid=192179887
      MERCHANTORDERNUMBER=5b42749552174e683282b5b0ddcd6459
      orderid=141640315
      PAYTYPE=Visa
      rcode=1101610001
      Reason=DECLINED:1101610001:Invalid account number:
      recurid=0
      result=0
      Status=Declined
      transid=0
      eos
    end
end