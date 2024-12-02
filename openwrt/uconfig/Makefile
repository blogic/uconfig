include $(TOPDIR)/rules.mk

PKG_NAME:=uconfig
PKG_RELEASE:=1

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
  SUBMENU:=uConfig
  TITLE:=UCI renderer
  DEPENDS=+ucode-mod-nl80211 +ucode-mod-rtnl +ucode-mod-ubus +ip-full +ip-bridge +ratelimit +pkgen
endef

define Package/uconfig-cli
  SECTION:=utils
  CATEGORY:=Utilities
  SUBMENU:=uConfig
  TITLE:=UCI renderer (CLI)
  DEPENDS=uconfig +cli
endef

define Package/uconfig-websocket
  SECTION:=utils
  CATEGORY:=Utilities
  SUBMENU:=uConfig
  TITLE:=UCI renderer (WebSocket)
  DEPENDS=uconfig +uwsd +pkgen +uconfig-cli +ucode-mod-log +ucode-mod-math
endef

define Package/uconfig-mod-mdns
  SECTION:=utils
  CATEGORY:=Utilities
  SUBMENU:=uConfig
  TITLE:=UCI renderer (MDNS plugin)
  DEPENDS=uconfig +umdns
endef

define Package/uconfig-mod-lldp
  SECTION:=utils
  CATEGORY:=Utilities
  SUBMENU:=uConfig
  TITLE:=UCI renderer (LLDP plugin)
  DEPENDS=uconfig +ulldpd
endef

define Package/uconfig-mod-ieee8021x
  SECTION:=utils
  CATEGORY:=Utilities
  SUBMENU:=uConfig
  TITLE:=UCI renderer (IEEE802.1x plugin)
  DEPENDS=uconfig +ucode-mod-log +ieee8021x
endef

define Package/uconfig-mod-mesh-batman
  SECTION:=utils
  CATEGORY:=Utilities
  SUBMENU:=uConfig
  TITLE:=UCI renderer (Mesh/Batman plugin)
  DEPENDS=uconfig +kmod-batman-adv
endef

define Package/uconfig-mod-adguardhome
  SECTION:=utils
  CATEGORY:=Utilities
  SUBMENU:=uConfig
  TITLE:=UCI renderer (adguardhome plugin)
  DEPENDS=uconfig +adguardhome
endef

define Package/uconfig-mod-fingerprint
  SECTION:=utils
  CATEGORY:=Utilities
  SUBMENU:=uConfig
  TITLE:=UCI renderer (fingerprint plugin)
  DEPENDS=uconfig +ufp +udhcpsnoop
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) $(CURDIR)/../../ $(PKG_BUILD_DIR)/
endef

define Build/Compile/Default

endef
Build/Compile = $(Build/Compile/Default)

define Package/uconfig/install
	$(INSTALL_DIR) $(1)/usr/share/ucode/ $(1)/usr/libexec/uconfig/ $(1)/etc/uconfig/data $(1)/sbin
	$(CP) $(PKG_BUILD_DIR)/render/{ureader,uconfig} $(1)/usr/share/ucode/
	$(CP) $(PKG_BUILD_DIR)/render/lib/* $(1)/usr/share/ucode/uconfig
	$(CP) $(PKG_BUILD_DIR)/render/system/*.uc $(1)/usr/libexec/uconfig
	$(CP) $(PKG_BUILD_DIR)/render/examples $(1)/etc/uconfig
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/render/uconfig_apply $(1)/sbin
	$(CP) ./files-render/* $(1)
	$(CP) ./files-tools/* $(1)
endef

define Package/uconfig-cli/install
	$(INSTALL_DIR) $(1)/usr/share/ucode/ $(1)/usr/sbin
	$(CP) $(PKG_BUILD_DIR)/cli $(1)/usr/share/ucode/
	$(LN) /usr/sbin/cli $(1)/usr/sbin/uconfig
endef

define Package/uconfig-websocket/install
	$(INSTALL_DIR) $(1)/usr/share/ucode/uconfig $(1)/www-uconfig/
	$(CP) $(PKG_BUILD_DIR)/websocket/ $(1)/usr/share/ucode/uconfig
	$(CP) $(PKG_BUILD_DIR)/www/* $(1)/www-uconfig/
	$(CP) ./files-websocket/* $(1)

	$(INSTALL_DIR) $(1)/usr/lib/ucode/uconfig/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/src/utils.so $(1)/usr/lib/ucode/uconfig/

	$(INSTALL_DIR) $(1)/usr/share/ucode/uconfig/templates/services/ $(1)/usr/share/ucode/ureader/
	$(CP) $(PKG_BUILD_DIR)/render/ureader-modules/schemaServiceWebui.uc $(1)/usr/share/ucode/ureader/
	$(CP) $(PKG_BUILD_DIR)/render/modules/webui/* $(1)/usr/share/ucode/uconfig/templates/services/
endef

define Package/uconfig-mod-mdns/install
	$(INSTALL_DIR) $(1)/etc/uci-defaults/ $(1)/usr/share/ucode/uconfig/templates/services/
	$(INSTALL_DIR) $(1)/usr/share/ucode/ureader/
	$(CP) ./modules/mdns.defaults $(1)/etc/uci-defaults/uconfig-mdns
	$(CP) $(PKG_BUILD_DIR)/render/ureader-modules/schemaServiceMdns.uc $(1)/usr/share/ucode/ureader/
	$(CP) $(PKG_BUILD_DIR)/render/modules/mdns/* $(1)/usr/share/ucode/uconfig/templates/services/
endef

define Package/uconfig-mod-fingerprint/install
	$(INSTALL_DIR) $(1)/etc/uci-defaults/ $(1)/usr/share/ucode/uconfig/templates/services/
	$(CP) ./modules/fingerprint.defaults $(1)/etc/uci-defaults/uconfig-fingerprint
	$(CP) $(PKG_BUILD_DIR)/render/modules/fingerprint/* $(1)/usr/share/ucode/uconfig/templates/services/
endef

define Package/uconfig-mod-adguardhome/install
	$(INSTALL_DIR) $(1)/usr/share/ucode/uconfig/templates/services/
	$(INSTALL_DIR) $(1)/usr/share/ucode/ureader/
	$(CP) $(PKG_BUILD_DIR)/render/ureader-modules/schemaServiceAdguardhome.uc $(1)/usr/share/ucode/ureader/
	$(CP) $(PKG_BUILD_DIR)/render/modules/adguardhome/*.uc $(1)/usr/share/ucode/uconfig/templates/services/
	$(CP) $(PKG_BUILD_DIR)/render/modules/adguardhome/*.yaml $(1)/usr/share/ucode/uconfig/
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
$(eval $(call BuildPackage,uconfig-cli))
$(eval $(call BuildPackage,uconfig-websocket))
$(eval $(call BuildPackage,uconfig-mod-mdns))
$(eval $(call BuildPackage,uconfig-mod-adguardhome))
$(eval $(call BuildPackage,uconfig-mod-lldp))
$(eval $(call BuildPackage,uconfig-mod-ieee8021x))
$(eval $(call BuildPackage,uconfig-mod-fingerprint))
$(eval $(call BuildPackage,uconfig-mod-mesh-batman))
