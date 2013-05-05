require 'spec_helper'

describe Unmangler::MSVC do

  it "keeps original name if not mangled" do
    s = "foo::bar(@)"
    Unmangler::MSVC.unmangle(s).should == s
  end

#  describe "#unmangle" do
#    it "raises error on bad input" do
#      lambda{
#        Unmangler::MSVC.unmangle("@TTabPage@$bctr")
#      }.should raise_error
#    end
#  end

  describe "#safe_unmangle" do
    it "raises no error and returns original on bad input" do
      s = "@TTabPage@$bctr"
      Unmangler::MSVC.safe_unmangle(s).should == s
    end
  end

  def self.check mangled, unmangled, test_no_args = true
    it "unmangles #{mangled}" do
      Unmangler::MSVC.unmangle(mangled).should == unmangled
    end

    it "unmangles #{mangled} w/o args" do
      x = unmangled.split('(').first.strip.
        gsub(/(public|private|protected): /,'').
        gsub(/(void|__ptr64|int|__thiscall|__cdecl|virtual|class|struct) /,'').
        strip

      Unmangler::MSVC.unmangle(mangled, :args => false).should == x
    end if test_no_args
  end

  check "?h@@YAXH@Z", "void __cdecl h(int)"
  check "?AFXSetTopLevelFrame@@YAXPAVCFrameWnd@@@Z", "void __cdecl AFXSetTopLevelFrame(class CFrameWnd *)"
  check "??0_Lockit@std@@QAE@XZ", "public: __thiscall std::_Lockit::_Lockit(void)"

  check "?SetAt@CString@@QAEXHD@Z", "public: void __thiscall CString::SetAt(int, char)"
  check "?LoadFrame@CMDIFrameWndEx@@UAEHIKPAVCWnd@@PAUCCreateContext@@@Z",
    "public: virtual int __thiscall CMDIFrameWndEx::LoadFrame(unsigned int, unsigned long, class CWnd *, struct CCreateContext *)"

  check "??0DNameStatusNode@@AEAA@W4DNameStatus@@@Z",
    "private: __cdecl DNameStatusNode::DNameStatusNode(enum DNameStatus) __ptr64"

  check "?Add@?$CArray@VCSize@@V1@@@QAEHVCSize@@@Z",
    "public: int __thiscall CArray<class CSize, class CSize>::Add(class CSize)"

  check "??$_Char_traits_cat@U?$char_traits@D@std@@@std@@YA?AU_Secure_char_traits_tag@0@XZ",
    "struct std::_Secure_char_traits_tag __cdecl std::_Char_traits_cat<struct std::char_traits<char> >(void)",
    false

  check "?dtor$0@?0???0CDockSite@@QEAA@XZ@4HA",
    "int `public: __cdecl CDockSite::CDockSite(void) __ptr64'::`1'::dtor$0",
    false
end
