use super::VeshellRenderer;
use crate::flutter_engine::view::FlutterFrameFence;
use smithay::backend::renderer::element::{Element, Id, Kind, RenderElement, UnderlyingStorage};
use smithay::backend::renderer::gles::GlesTexture;
use smithay::backend::renderer::sync::SyncPoint;
use smithay::backend::renderer::utils::{CommitCounter, DamageSet, DamageSnapshot, OpaqueRegions};
use smithay::backend::renderer::{ContextId, Frame, Renderer, Texture};
use smithay::utils::user_data::UserDataMap;
use smithay::utils::{Buffer, Logical, Physical, Point, Rectangle, Scale, Size, Transform};
use tracing::warn;

/// Smithay's texture buffer, but with fractional scale.
#[derive(Debug, Clone)]
pub struct FractionnalTextureBuffer<T: Texture> {
    id: Id,
    /// What changed in the texture, commit after commit.
    damage: DamageSnapshot<i32, Buffer>,
    renderer_context_id: ContextId<T>,
    texture: T,
    scale: Scale<f64>,
    transform: Transform,
    opaque_regions: Vec<Rectangle<i32, Buffer>>,
    /// Reached once the texture's content is rendered: drawing waits for it.
    sync: SyncPoint,
}

/// Render element for a [`TextureBuffer`].
#[derive(Debug, Clone)]
pub struct FractionnalTextureRenderElement<T: Texture> {
    buffer: FractionnalTextureBuffer<T>,
    location: Point<f64, Logical>,
    alpha: f32,
    src: Option<Rectangle<f64, Logical>>,
    size: Option<Size<f64, Logical>>,
    kind: Kind,
}

impl<T: Texture> FractionnalTextureBuffer<T> {
    pub fn from_texture<R: Renderer<TextureId = T>>(
        renderer: &R,
        texture: T,
        scale: impl Into<Scale<f64>>,
        transform: Transform,
        opaque_regions: Vec<Rectangle<i32, Buffer>>,
    ) -> Self {
        FractionnalTextureBuffer {
            id: Id::new(),
            damage: DamageSnapshot::empty(),
            renderer_context_id: renderer.context_id(),
            texture,
            scale: scale.into(),
            transform,
            opaque_regions,
            sync: SyncPoint::signaled(),
        }
    }
}

impl<T: Texture> FractionnalTextureBuffer<T> {
    /// Reuses an identity across composites: the same `id` with an unchanged
    /// `damage` reads as an undamaged element to the damage tracker, and a new
    /// commit repaints only the part of it that commit changed.
    pub fn with_identity(mut self, id: Id, damage: DamageSnapshot<i32, Buffer>) -> Self {
        self.id = id;
        self.damage = damage;
        self
    }

    /// The texture is still being rendered (by another context) until `sync`
    /// is reached: every draw of it waits for that first.
    pub fn with_sync(mut self, sync: SyncPoint) -> Self {
        self.sync = sync;
        self
    }

    pub fn logical_size(&self) -> Size<f64, Logical> {
        self.texture
            .size()
            .to_f64()
            .to_logical(self.scale, self.transform)
    }
}

impl<T: Texture> FractionnalTextureRenderElement<T> {
    pub fn from_texture_buffer(
        buffer: FractionnalTextureBuffer<T>,
        location: impl Into<Point<f64, Logical>>,
        alpha: f32,
        src: Option<Rectangle<f64, Logical>>,
        size: Option<Size<f64, Logical>>,
        kind: Kind,
    ) -> Self {
        FractionnalTextureRenderElement {
            buffer,
            location: location.into(),
            alpha,
            src,
            size,
            kind,
        }
    }
}

impl<T: Texture> FractionnalTextureRenderElement<T> {
    /// A rectangle of the texture, where it is drawn relative to the
    /// element; `None` outside the part drawn.
    fn buffer_to_local(&self, rect: Rectangle<f64, Buffer>) -> Option<Rectangle<f64, Logical>> {
        let src = self.src();
        // The source rectangle is drawn at `logical_size()`, which differs
        // from its own logical size when a viewport stretches it.
        let src_logical_size = src
            .size
            .to_logical(self.buffer.scale, self.buffer.transform);
        let stretch = self.logical_size() / src_logical_size;

        let mut rect = rect.intersection(src)?;
        rect.loc -= src.loc;
        Some(
            rect.to_logical(self.buffer.scale, self.buffer.transform, &src.size)
                .upscale(stretch),
        )
    }

    pub fn logical_size(&self) -> Size<f64, Logical> {
        self.size
            .or_else(|| self.src.map(|src| src.size))
            .unwrap_or_else(|| self.buffer.logical_size())
    }
}

impl<T: Texture> Element for FractionnalTextureRenderElement<T> {
    fn id(&self) -> &Id {
        &self.buffer.id
    }

    fn current_commit(&self) -> CommitCounter {
        self.buffer.damage.current_commit()
    }

    fn geometry(&self, scale: Scale<f64>) -> Rectangle<i32, Physical> {
        let logical_geo = Rectangle::new(self.location, self.logical_size());
        logical_geo.to_physical_precise_round(scale)
    }

    fn transform(&self) -> Transform {
        self.buffer.transform
    }

    fn src(&self) -> Rectangle<f64, Buffer> {
        self.src
            .map(|src| {
                src.to_buffer(
                    self.buffer.scale,
                    self.buffer.transform,
                    &self.buffer.logical_size(),
                )
            })
            .unwrap_or_else(|| Rectangle::from_size(self.buffer.texture.size()).to_f64())
    }

    fn damage_since(
        &self,
        scale: Scale<f64>,
        commit: Option<CommitCounter>,
    ) -> DamageSet<i32, Physical> {
        let size = self.geometry(scale).size;
        let Some(damage) = self.buffer.damage.damage_since(commit) else {
            return DamageSet::from_slice(&[Rectangle::from_size(size)]);
        };
        damage
            .iter()
            .filter_map(|rect| {
                let rect = self
                    .buffer_to_local(rect.to_f64())?
                    .to_physical_precise_up(scale);
                // A pixel more on every side: the element's own position is
                // rounded, and a stretched texture's filtering reaches the
                // pixels next to those that changed.
                Rectangle::new(
                    rect.loc - Point::from((1, 1)),
                    rect.size + Size::from((2, 2)),
                )
                .intersection(Rectangle::from_size(size))
            })
            .collect()
    }

    fn opaque_regions(&self, scale: Scale<f64>) -> OpaqueRegions<i32, Physical> {
        self.buffer
            .opaque_regions
            .iter()
            .filter_map(|region| {
                Some(
                    self.buffer_to_local(region.to_f64())?
                        .to_physical_precise_down(scale),
                )
            })
            .collect()
    }

    fn alpha(&self) -> f32 {
        self.alpha
    }

    fn kind(&self) -> Kind {
        self.kind
    }
}

/// Drawn through the render GPU's GLES frame: the Flutter texture lives on the
/// render GPU, including when the output is on another GPU (see
/// [`VeshellRenderer`]).
impl<R: VeshellRenderer> RenderElement<R> for FractionnalTextureRenderElement<GlesTexture> {
    fn draw(
        &self,
        frame: &mut R::Frame<'_, '_>,
        src: Rectangle<f64, Buffer>,
        dest: Rectangle<i32, Physical>,
        damage: &[Rectangle<i32, Physical>],
        opaque_regions: &[Rectangle<i32, Physical>],
        _cache: Option<&UserDataMap>,
    ) -> Result<(), R::Error> {
        let frame = R::as_gles_frame(frame);
        if frame.context_id() != self.buffer.renderer_context_id {
            warn!("trying to render texture from different renderer");
            return Ok(());
        }

        let sync = &self.buffer.sync;
        if !sync.is_reached() {
            // On the GPU, in this frame's context, when the fence is on its
            // display; otherwise the renderer imports it or blocks.
            let inserted = sync
                .get::<FlutterFrameFence>()
                .is_some_and(FlutterFrameFence::wait_in_current_context);
            if !inserted {
                frame.wait(sync).map_err(R::gles_error)?;
            }
        }
        // The trait method: `GlesFrame` has an inherent one that also takes a
        // shader program.
        Frame::render_texture_from_to(
            frame,
            &self.buffer.texture,
            src,
            dest,
            damage,
            opaque_regions,
            self.buffer.transform,
            self.alpha,
        )
        .map_err(R::gles_error)
    }

    fn underlying_storage(&self, _renderer: &mut R) -> Option<UnderlyingStorage<'_>> {
        None
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use smithay::backend::allocator::Fourcc;
    use smithay::backend::renderer::utils::DamageBag;

    #[derive(Debug, Clone)]
    struct FakeTexture(Size<i32, Buffer>);

    impl Texture for FakeTexture {
        fn width(&self) -> u32 {
            self.0.w as u32
        }
        fn height(&self) -> u32 {
            self.0.h as u32
        }
        fn format(&self) -> Option<Fourcc> {
            None
        }
    }

    /// A 1280×800 view at scale 1.2, flipped as GL stores Flutter's frames.
    fn element(
        damage: DamageSnapshot<i32, Buffer>,
    ) -> FractionnalTextureRenderElement<FakeTexture> {
        let buffer = FractionnalTextureBuffer {
            id: Id::new(),
            damage,
            renderer_context_id: ContextId::new(),
            texture: FakeTexture((1536, 960).into()),
            scale: 1.2.into(),
            transform: Transform::Flipped180,
            opaque_regions: Vec::new(),
            sync: SyncPoint::signaled(),
        };
        FractionnalTextureRenderElement::from_texture_buffer(
            buffer,
            (0.0, 0.0),
            1.0,
            None,
            Some((1280.0, 800.0).into()),
            Kind::Unspecified,
        )
    }

    #[test]
    fn a_frame_damages_only_what_it_changed_upside_up() {
        let mut bag = DamageBag::default();
        bag.add([Rectangle::<i32, Buffer>::new(
            (100, 0).into(),
            (10, 10).into(),
        )]);
        let before = bag.current_commit();
        bag.add([Rectangle::<i32, Buffer>::new(
            (200, 950).into(),
            (4, 10).into(),
        )]);
        let element = element(bag.snapshot());

        let damage = element.damage_since(1.2.into(), Some(before));
        let [damage] = damage.iter().copied().collect::<Vec<_>>()[..] else {
            panic!("one rectangle expected, got {damage:?}");
        };
        // GL's rows run up: the texture's top rows are the screen's top
        // ones once flipped. The 4×10 texels are 3.33×8.33 logical pixels,
        // 4×10 physical ones from (200, 0), and a pixel of margin around.
        let changed = Rectangle::<i32, Physical>::new((200, 0).into(), (4, 10).into());
        assert!(damage.contains_rect(changed), "{damage:?}");
        assert!(
            damage.size.w <= 4 + 3 && damage.size.h <= 10 + 2,
            "{damage:?}"
        );
    }

    #[test]
    fn a_commit_out_of_history_damages_the_whole_element() {
        let mut bag = DamageBag::default();
        bag.add([Rectangle::<i32, Buffer>::new(
            (100, 0).into(),
            (10, 10).into(),
        )]);
        bag.reset();
        let element = element(bag.snapshot());

        let damage = element.damage_since(1.2.into(), None);
        assert_eq!(
            damage.iter().copied().collect::<Vec<_>>(),
            vec![Rectangle::<i32, Physical>::from_size((1536, 960).into())],
        );
    }

    #[test]
    fn the_same_commit_damages_nothing() {
        let mut bag = DamageBag::default();
        bag.add([Rectangle::<i32, Buffer>::new(
            (100, 0).into(),
            (10, 10).into(),
        )]);
        let element = element(bag.snapshot());

        assert!(element
            .damage_since(1.2.into(), Some(bag.current_commit()))
            .is_empty());
    }
}
