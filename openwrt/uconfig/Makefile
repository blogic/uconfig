include $(TOPDIR)/rules.mk

PKG_NAME:=uconfig
PKG_RELEASE:=1

PKG_FILE_DEPENDS := $(CURDIR)/../../

PKG_MAINTAINER:=John Crispin <john@phrozen.org>
PKG_LICENSE:=ISC

include $(INCLUDE_DIR)/package.mk

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

define Package/uconfig-mod-lldp
  SECTION:=utils
  CATEGORY:=Utilities
  SUBMENU:=uconfig
  TITLE:=UCI renderer (LLDP plugin)
  DEPENDS+=uconfig +ulldpd
endef

define Package/uconfig-mod-ieee8021x
  SECTION:=utils
  CATEGORY:=Utilities
  SUBMENU:=uconfig
  TITLE:=UCI renderer (IEEE802.1x plugin)
  DEPENDS+=uconfig +ucode-mod-log +ieee8021x
endef

define Package/uconfig-mod-mesh-batman
  SECTION:=utils
  CATEGORY:=Utilities
  SUBMENU:=uconfig
  TITLE:=UCI renderer (Mesh/Batman plugin)
  DEPENDS+=uconfig +kmod-batman-adv
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) $(CURDIR)/../../ $(PKG_BUILD_DIR)/
endef

define Build/Compile/Default

endef
Build/Compile = $(Build/Compile/Default)

define Package/uconfig/install
	$(INSTALL_DIR) $(1)/usr/share/ucode/ $(1)/usr/libexec/uconfig/ $(1)/etc/uconfig $(1)/sbin
	$(CP) $(PKG_BUILD_DIR)/render/{ureader,uconfig} $(1)/usr/share/ucode/
	$(CP) $(PKG_BUILD_DIR)/render/lib/* $(1)/usr/share/ucode/uconfig
	$(CP) $(PKG_BUILD_DIR)/render/system/*.uc $(1)/usr/libexec/uconfig
	$(CP) $(PKG_BUILD_DIR)/render/examples $(1)/etc/uconfig
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/render/uconfig_apply $(1)/sbin
	$(CP) ./files-render/* $(1)
endef

define Package/uconfig-mod-mdns/install
	$(INSTALL_DIR) $(1)/etc/uci-defaults/ $(1)/usr/share/ucode/uconfig/templates/services/
	$(INSTALL_DIR) $(1)/usr/share/ucode/ureader/
	$(CP) ./modules/mdns.defaults $(1)/etc/uci-defaults/uconfig-mdns
	$(CP) $(PKG_BUILD_DIR)/render/ureader-modules/schemaServiceMdns.uc $(1)/usr/share/ucode/ureader/
	$(CP) $(PKG_BUILD_DIR)/render/modules/mdns/* $(1)/usr/share/ucode/uconfig/templates/services/
endef

define Package/uconfig-mod-lldp/install
	$(INSTALL_DIR) $(1)/etc/uci-defaults/ $(1)/usr/share/ucode/uconfig/templates/services/
	$(INSTALL_DIR) $(1)/usr/share/ucode/ureader/
	$(CP) ./modules/lldp.defaults $(1)/etc/uci-defaults/uconfig-lldp
	$(CP) $(PKG_BUILD_DIR)/render/ureader-modules/schemaServiceLldp.uc $(1)/usr/share/ucode/ureader/
	$(CP) $(PKG_BUILD_DIR)/render/modules/lldp/* $(1)/usr/share/ucode/uconfig/templates/services/
endef

define Package/uconfig-mod-ieee8021x/install
	$(INSTALL_DIR) $(1)/etc/uci-defaults/ $(1)/usr/share/ucode/uconfig/templates/services/
	$(INSTALL_DIR) $(1)/usr/share/ucode/ureader/
	$(CP) $(PKG_BUILD_DIR)/render/ureader-modules/schemaServiceIeee8021x.uc $(1)/usr/share/ucode/ureader/
	$(CP) $(PKG_BUILD_DIR)/render/modules/ieee8021x/* $(1)/usr/share/ucode/uconfig/templates/services/
endef

define Package/uconfig-mod-mesh-batman/install
	$(INSTALL_DIR) $(1)/etc/uci-defaults/
endef

$(eval $(call BuildPackage,uconfig))
$(eval $(call BuildPackage,uconfig-mod-mdns))
$(eval $(call BuildPackage,uconfig-mod-lldp))
$(eval $(call BuildPackage,uconfig-mod-ieee8021x))
$(eval $(call BuildPackage,uconfig-mod-mesh-batman))
