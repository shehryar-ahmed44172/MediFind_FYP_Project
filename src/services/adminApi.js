import api from './api';

export const PLAN_OPTIONS = [
  { value: 'FREE',         label: 'Free',       price: 0 },
  { value: 'PROFESSIONAL', label: 'Pro',        price: 499 },
  { value: 'EXECUTIVE',    label: 'Executive',  price: 2499 },
];

/**
 * Change a user's subscription plan.
 * PATCH /api/admin/users/:id/subscription  { plan }  →  { success, data: { id, subscriptionPlan } }
 * Resolves with the new plan value; rejects with a readable Error.
 */
export async function updateSubscriptionPlan(userId, plan) {
  try {
    const res = await api.patch(`/api/admin/users/${userId}/subscription`, { plan });
    if (!res.data?.success) throw new Error(res.data?.message || 'Plan update was rejected.');
    return res.data.data?.subscriptionPlan ?? plan;
  } catch (err) {
    const serverMsg = err.response?.data?.message;
    const message = serverMsg
      || (err.response?.status === 404 ? 'Plan changes are not available on this server yet.' : null)
      || err.message
      || 'Failed to update the subscription plan.';
    throw new Error(message);
  }
}

/** Human-readable message from an axios error */
export const errorMessage = (err, fallback = 'Something went wrong.') =>
  err?.response?.data?.message || (err?.request && !err?.response ? 'Cannot reach the server. Check your connection.' : null) || err?.message || fallback;
