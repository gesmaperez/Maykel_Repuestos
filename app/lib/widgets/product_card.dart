import 'package:flutter/material.dart';

import '../config.dart';
import '../models.dart';

/// Tarjeta de producto del catálogo público: SKU, categoría, nombre,
/// marca/modelo y una insignia de estado (Agotado / Últimas N / Disponible),
/// igual que en el diseño original.
class ProductCard extends StatelessWidget {
  final Repuesto producto;
  final VoidCallback onReservar;

  const ProductCard({
    super.key,
    required this.producto,
    required this.onReservar,
  });

  @override
  Widget build(BuildContext context) {
    final stock = producto.stock;
    final agotado = stock <= 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.paper2),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 96,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.char,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  child: Text(
                    producto.sku,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: _StockBadge(stock: stock),
                ),
                const Align(
                  alignment: Alignment.center,
                  child: Icon(Icons.settings, color: Colors.white24, size: 32),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  producto.categoria.isEmpty ? 'General' : producto.categoria,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.red,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  producto.nombre,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.char,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (producto.marca.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    producto.modelo.isNotEmpty
                        ? '${producto.marca} · ${producto.modelo}'
                        : producto.marca,
                    style: TextStyle(fontSize: 12, color: AppColors.steel),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: agotado ? null : onReservar,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                    child: Text(agotado ? 'Agotado' : 'Reservar'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StockBadge extends StatelessWidget {
  final num stock;
  const _StockBadge({required this.stock});

  @override
  Widget build(BuildContext context) {
    late final Color color;
    late final String texto;
    if (stock <= 0) {
      color = AppColors.bad;
      texto = 'Agotado';
    } else if (stock <= 3) {
      color = AppColors.warn;
      texto = 'Últimas $stock';
    } else {
      color = AppColors.ok;
      texto = 'Disponible';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
