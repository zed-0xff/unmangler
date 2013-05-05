require 'spec_helper'

describe Unmangler::Borland do

  it "keeps original name if not mangled" do
    s = "foo::bar(@)"
    Unmangler::Borland.unmangle(s).should == s
  end

  describe "#unmangle" do
    it "raises error on bad input" do
      lambda{
        Unmangler::Borland.unmangle("@TTabPage@$bctr")
      }.should raise_error
    end
  end

  describe "#safe_unmangle" do
    it "raises no error and returns original on bad input" do
      s = "@TTabPage@$bctr"
      Unmangler::Borland.safe_unmangle(s).should == s
    end
  end

  def self.check mangled, unmangled
    it "unmangles #{mangled}" do
      Unmangler::Borland.unmangle(mangled).should == unmangled
    end

    it "unmangles #{mangled} w/o args" do
      x = unmangled.split('(').first.strip.sub(/^__fastcall /,'')
      Unmangler::Borland.unmangle(mangled, :args => false).should == x
    end
  end

  check "@afunc$qxzcupi",   "afunc(const signed char, int *)"
  check "@foo$qpqfi$d",     "foo(double (*)(float, int))"
  check "@myclass@func$qil","myclass::func(int, long)"

  check "@Sysinit@@InitExe$qqrpv",
    "__fastcall Sysinit::__linkproc__ InitExe(void *)"

  check "@Forms@TApplication@SetTitle$qqrx17System@AnsiString",
    "__fastcall Forms::TApplication::SetTitle(const System::AnsiString)"

  check "@Forms@TApplication@CreateForm$qqrp17System@TMetaClasspv",
    "__fastcall Forms::TApplication::CreateForm(System::TMetaClass *, void *)"

  check "@System@@LStrCatN$qqrv", "__fastcall System::__linkproc__ LStrCatN()"

  check "@System@DynArraySetLength$qqrrpvpvipi",
    "__fastcall System::DynArraySetLength(void *&, void *, int, int *)"

  check "@System@Variant@PutElement$qqrrx14System@Variantxixi",
    "__fastcall System::Variant::PutElement(System::Variant&, const int, const int)"

  check "@Windows@HwndMSWheel$qqrruit1t1rit4",
    "__fastcall Windows::HwndMSWheel(unsigned int&, unsigned int&, unsigned int&, int&, int&)"

  # IDA uses '__int64' instead of 'long long'
  check "@Sysutils@TryStrToInt64$qqrx17System@AnsiStringrj",
    "__fastcall Sysutils::TryStrToInt64(const System::AnsiString, long long&)"

  check "@Sysutils@Supports$qqrpx14System@TObjectrx5_GUIDpv",
    "__fastcall Sysutils::Supports(System::TObject *, _GUID&, void *)"

  check "@std@%vector$51boost@archive@detail@basic_iarchive_impl@cobject_id69std@%allocator$51boost@archive@detail@basic_iarchive_impl@cobject_id%%@$bsubs$qui",
    "std::vector<boost::archive::detail::basic_iarchive_impl::cobject_id, std::allocator<boost::archive::detail::basic_iarchive_impl::cobject_id> >::operator [](unsigned int)"

  check "@Dbcommon@GetTableNameFromSQLEx$qqrx17System@WideString25Dbcommon@IDENTIFIEROption",
    "__fastcall Dbcommon::GetTableNameFromSQLEx(const System::WideString, Dbcommon::IDENTIFIEROption)"

  check '@Classes@TThread@$bcdtr$qqrv',    '__fastcall Classes::TThread::`class destructor`()'
  check '@Timespan@TTimeSpan@$bcctr$qqrv', '__fastcall Timespan::TTimeSpan::`class constructor`()'
end
