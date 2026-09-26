-- ==============================================================================
-- PRINTORA AUTOMATED PRINTING VENDING MACHINE - SEED DATA
-- Machine: printer001
-- ==============================================================================

INSERT INTO machines (
    id,
    location,
    status,
    mqtt_client_id,
    last_seen_at,
    paper_status,
    ink_status,
    printer_status,
    maintenance_mode
) VALUES (
    'printer001',
    'Tech Hub Center - Main Lobby Kiosk',
    'ONLINE',
    'client_printer001',
    NOW(),
    'OK',
    'OK',
    'IDLE',
    FALSE
) ON CONFLICT (id) DO UPDATE SET
    status = EXCLUDED.status,
    paper_status = EXCLUDED.paper_status,
    ink_status = EXCLUDED.ink_status,
    printer_status = EXCLUDED.printer_status,
    last_seen_at = NOW();
