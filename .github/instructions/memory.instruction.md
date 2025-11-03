---
applyTo: '**'
---

# Memory Instructions

## Code Documentation Standards

### JSDoc Usage
- **ALWAYS** use JSDoc notation when modifying JavaScript and TypeScript files
- Include comprehensive JSDoc comments for:
  - All classes with `@class` tag
  - All interfaces with `@interface` tag  
  - All public and private methods with `@param`, `@returns`, `@throws` tags
  - All properties with `@type`, `@memberof` tags
  - Add `@example` blocks for public methods where helpful
  - Use `@private`, `@readonly`, `@optional` tags where applicable

### JSDoc Example Format
```typescript
/**
 * Service for handling customer authorization and policy access capabilities.
 * Uses dependency injection for logger and insurance policies client.
 * 
 * @class AuthService
 * @example
 * ```typescript
 * const authService = new AuthService({
 *   logger: myLogger,
 *   insurancePoliciesClient: new InsurancePoliciesClient({ env: 'dev', logger: myLogger })
 * });
 * ```
 */
export class AuthService {
  /**
   * Logger instance for structured logging
   * 
   * @private
   * @readonly
   * @type {ILogger}
   * @memberof AuthService
   */
  private readonly _logger: ILogger;

  /**
   * Check if a customer can view any policies
   * 
   * @param {IGetInsurancePoliciesV2Request} request - Request parameters for fetching customer policies
   * @returns {Promise<boolean>} True if user can view any policy, false otherwise or on error
   * @memberof AuthService
   * @example
   * ```typescript
   * const canView = await authService.canViewPolicies({ customerId: '12345' });
   * ```
   */
  async canViewPolicies(request: IGetInsurancePoliciesV2Request): Promise<boolean> {
    // Implementation
  }
}
```

## Project Context

This is the `insurance-self-service_common_package` repository containing shared TypeScript libraries and clients for insurance-related services. The codebase uses:
- TypeScript with strict typing
- Dependency injection patterns
- Structured logging interfaces
- Insurance policy management APIs
- JSDoc for comprehensive documentation

