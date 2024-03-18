include $(TOPDIR)/rules.mk

PKG_NAME:=uconfig
PKG_RELEASE:=1

PKG_VERSION:=$(shell git log -n1 --format=format:%cd-%h --date=iso --date=short)
PKG_FILE_DEPENDS := $(CURDIR)/../../

PKG_MAINTAINER:=John Crispin <john@phrozen.org>
PKG_LICENSE:=ISC

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/cmake.mk

CMAKE_SOURCE_DIR:=$(PKG_BUILD_DIR)/src
CMAKE_BINARY_DIR:=$(PKG_BUILD_DIR)/src

define Package/uconfig
  SECTION:=utils
  CATEGORY:=Utilities
  SUBMENU:=uconfig
  TITLE:=UCI renderer
  DEPENDS+=+ucode-mod-nl80211 +ucode-mod-rtnl +ip-full +ip-bridge +ratelimit
endef

define Package/uconfig-mod-mdns
  SECTION:=utils
  CATEGORY:=Utilities
  SUBMENU:=uconfig
  TITLE:=UCI renderer (MDNS plugin)
  DEPENDS+=uconfig +umdns
endef

define Package/uconfig-mod-mesh-batman
  SECTION:=utils
  CATEGORY:=Utilities
  SUBMENU:=uconfig
  TITLE:=UCI renderer (Mesh/Batman plugin)
  DEPENDS+=uconfig +kmod-batman-adv
endef

define Package/uconfig-state
  SECTION:=utils
  CATEGORY:=Utilities
  SUBMENU:=uconfig
  TITLE:=state
  DEPENDS+=+uconfig +udhcpsnoop +ufp +udhcpsnoop +uconfig-mod-mdns
endef

define Package/uconfig-server
  SECTION:=utils
  CATEGORY:=Utilities
  SUBMENU:=uconfig
  TITLE:=server
  DEPENDS+=+ucode-mod-log +ucode-mod-math +uwsd +uconfig +uconfig-state
endef

define Package/uconfig-device
  SECTION:=utils
  CATEGORY:=Utilities
  SUBMENU:=uconfig
  TITLE:=device
  DEPENDS+=+ucode-mod-log +ucode-mod-math +uconfig +libwebsockets
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) $(CURDIR)/../../ $(PKG_BUILD_DIR)/
endef

define Package/uconfig/install
	$(INSTALL_DIR) $(1)/usr/share/ucode/ $(1)/usr/libexec/uconfig/ $(1)/etc/uconfig $(1)/sbin
	$(CP) $(PKG_BUILD_DIR)/render/{ureader,uconfig} $(1)/usr/share/ucode/
	$(CP) $(PKG_BUILD_DIR)/render/lib/* $(1)/usr/share/ucode/uconfig
	$(CP) $(PKG_BUILD_DIR)/render/system/*.uc $(1)/usr/libexec/uconfig
	$(CP) $(PKG_BUILD_DIR)/render/examples $(1)/etc/uconfig
	$(CP) $(PKG_BUILD_DIR)/render/examples/factory.json $(1)/etc/uconfig/uconfig.cfg.0000000001
	$(LN) /etc/uconfig/uconfig.cfg.0000000001 $(1)/etc/uconfig/uconfig.active
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/render/render_config $(1)/sbin
	$(CP) ./files-render/* $(1)
endef

define Package/uconfig-mod-mdns/install
	$(INSTALL_DIR) $(1)/etc/uci-defaults/ $(1)/usr/share/ucode/uconfig/templates/services/
	$(INSTALL_DIR) $(1)/usr/share/ucode/ureader/
	$(CP) ./modules/mdns.defaults $(1)/etc/uci-defaults/zzz-uconfig-mdns
	$(CP) $(PKG_BUILD_DIR)/render/ureader-modules/schemaServiceMdns.uc $(1)/usr/share/ucode/ureader/
	$(CP) $(PKG_BUILD_DIR)/render/modules/mdns/* $(1)/usr/share/ucode/uconfig/templates/services/
endef

define Package/uconfig-mod-mesh-batman/install
	$(INSTALL_DIR) $(1)/etc/uci-defaults/
endef

define Package/uconfig-state/install
	$(INSTALL_DIR) $(1)/usr/share/ucode/uconfig
	$(CP) $(PKG_BUILD_DIR)/state/* $(1)/usr/share/ucode/uconfig
endef

define Package/uconfig-server/install
	$(INSTALL_DIR) $(1)/usr/share/ucode/uconfig $(1)/usr/lib/ucode/uconfig/
	$(CP) $(PKG_BUILD_DIR)/server $(1)/usr/share/ucode/uconfig
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/src/utils.so $(1)/usr/lib/ucode/uconfig/
	$(CP) ./files-server/* $(1)
	mv $(1)/usr/share/ucode/uconfig/server/www/ $(1)/www-uconfig
endef

define Package/uconfig-device/install
	$(INSTALL_DIR) $(1)/usr/bin $(1)/usr/lib/ucode/uconfig/ $(1)/usr/share/ucode/uconfig/device/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/uconfig-device $(1)/usr/bin
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/device/* $(1)/usr/share/ucode/uconfig/device/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/src/device.so $(1)/usr/lib/ucode/uconfig/
endef

$(eval $(call BuildPackage,uconfig))
$(eval $(call BuildPackage,uconfig-mod-mdns))
$(eval $(call BuildPackage,uconfig-mod-mesh-batman))
$(eval $(call BuildPackage,uconfig-state))
$(eval $(call BuildPackage,uconfig-server))
$(eval $(call BuildPackage,uconfig-device))
