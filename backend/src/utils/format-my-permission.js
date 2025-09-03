const { getAccessItemHierarchy } = require("./get-access-item-hierarchy");

const formatMyPermission = (permissions) => {
    // De-duplicate by unique combination of type+path to avoid duplicate UI/menu entries
    const seen = new Set();
    const uniquePermissions = permissions.filter((p) => {
        const key = `${p.type}:${p.path}`;
        if (seen.has(key)) return false;
        seen.add(key);
        return true;
    });

    const menuList = ["menu", "menu-screen"];
    const menus = uniquePermissions.filter(p => menuList.includes(p.type));
    const hierarchialMenus = getAccessItemHierarchy(menus);
    const uis = uniquePermissions.filter(p => p.type !== "api");
    const apis = uniquePermissions.filter(p => p.type === "api");

    return {
        hierarchialMenus,
        uis,
        apis
    }
}

module.exports = { formatMyPermission };