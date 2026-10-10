package example.allycore.components;

import example.allycore.adapters.DomainAdapter;

public final class AllyCoreApplication {
    private AllyCoreApplication() {}

    public static void main(String[] args) {
        System.out.println(new DomainAdapter().greeting());
    }
}
