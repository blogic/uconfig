include $(TOPDIR)/rules.mk

PKG_NAME:=uwsd

PKG_SOURCE_URL=https://github.com/jow-/uwsd.git
PKG_MIRROR_HASH:=de86830b320ffcf67ca3ae37289b7c8cc126b4a5475a8ff445ace1d9bcc68263
PKG_SOURCE_PROTO:=git
PKG_SOURCE_DATE:=2024-02-09
PKG_SOURCE_VERSION:=9e01624450c901e75170b67455a93b81bb3f258a

PKG_MAINTAINER:=Jo-Philipp Wich <jo@mein.io>
PKG_LICENSE:=ISC

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/cmake.mk

define Package/uwsd
  SECTION:=net
  CATEGORY:=Network
  TITLE:=uwsd
  DEPENDS:=+libubox +ucode +libopenssl
endef

CMAKE_OPTIONS+=-DDEBUG=YES -DCMAKE_BUILD_TYPE=Debug
EXTRA_CFLAGS=-Wno-error=unused-function

define Package/uwsd/install
	$(INSTALL_DIR) $(1)/usr/sbin 
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/uwsd $(1)/usr/sbin/
endef

$(eval $(call BuildPackage,uwsd))
