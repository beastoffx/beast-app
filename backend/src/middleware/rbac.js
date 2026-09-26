function authorizeRoles(...allowedRoles) {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        success: false,
        error: 'Unauthorized. Authentication required.'
      });
    }

    // Super Admin inherits admin privileges
    if (allowedRoles.includes('admin') && (req.user.isSuperAdmin || req.user.role === 'super_admin')) {
      return next();
    }

    // Explicit super_admin role check
    if (allowedRoles.includes('super_admin') && (req.user.isSuperAdmin || req.user.role === 'super_admin')) {
      return next();
    }

    if (!allowedRoles.includes(req.user.role)) {
      return res.status(403).json({
        success: false,
        error: `Forbidden. Role '${req.user.role}' lacks permission to perform this action.`,
        requiredRoles: allowedRoles
      });
    }

    next();
  };
}

function authorizeSuperAdmin(req, res, next) {
  if (!req.user) {
    return res.status(401).json({
      success: false,
      error: 'Unauthorized. Authentication required.'
    });
  }

  if (!req.user.isSuperAdmin && req.user.role !== 'super_admin') {
    return res.status(403).json({
      success: false,
      error: 'Forbidden. This operation requires Super Admin institutional authority.'
    });
  }

  next();
}

function authorizePermission(permission) {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        success: false,
        error: 'Unauthorized. Authentication required.'
      });
    }

    // Super Admin has all permissions automatically
    if (req.user.isSuperAdmin || req.user.role === 'super_admin') {
      return next();
    }

    // Admin with specific permission or 'all' wildcard
    if (req.user.role === 'admin') {
      const perms = req.user.permissions || {};
      if (perms[permission] || perms.all) {
        return next();
      }
    }

    return res.status(403).json({
      success: false,
      error: `Forbidden. Missing required administrative permission: ${permission}.`
    });
  };
}

module.exports = {
  authorizeRoles,
  authorizeSuperAdmin,
  authorizePermission
};
