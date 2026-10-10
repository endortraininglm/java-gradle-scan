package example.allycore.adapters;

import example.allycore.api.AllyCoreApi;
import example.allycore.domain.DomainService;

public final class DomainAdapter implements AllyCoreApi {
    private final DomainService domainService = new DomainService();

    @Override
    public String greeting() {
        return domainService.greeting();
    }
}
