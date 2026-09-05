plugins {
    id("com.android.asset-pack")
}

assetPack {
    packName.set("mushaf_pages_pack")
    dynamicDelivery {
        deliveryType.set("install-time")
    }
}
